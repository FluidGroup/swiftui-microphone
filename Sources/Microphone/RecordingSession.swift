import AVFAudio
import Foundation
import Observation

@MainActor @Observable
final class RecordingSession: NSObject, AVAudioRecorderDelegate {

  private(set) var status = MicrophoneStatus.idle
  var isVisible = false

  // AVAudioSession is process-wide. Only its current owner can deactivate it.
  private static weak var owner: RecordingSession?
  @ObservationIgnored private var permissionTask: Task<Void, Never>?
  @ObservationIgnored private var recorder: AVAudioRecorder?
  @ObservationIgnored private var file: MicrophoneRecording?
  @ObservationIgnored private var receive: (@MainActor (MicrophoneRecording) async -> Void)?
  @ObservationIgnored private var restoreCategory: (() -> Void)?
  @ObservationIgnored private let permission: @MainActor () async -> Bool

  init(permission: @escaping @MainActor () async -> Bool = { await AVAudioApplication.requestRecordPermission() }) {
    self.permission = permission
  }

  func start(
    maximumDuration: TimeInterval?,
    receive: @escaping @MainActor (MicrophoneRecording) async -> Void
  ) {
    guard isVisible, status != .recording, status != .requestingPermission else {
      return
    }
    if let maximumDuration, !maximumDuration.isFinite || maximumDuration <= 0 {
      status = .failed("Recording duration must be finite and positive.")
      return
    }
    status = .requestingPermission
    permissionTask = Task {
      let granted = await permission()
      guard !Task.isCancelled, isVisible else {
        return
      }
      permissionTask = nil
      guard granted else {
        status = .accessDenied
        return
      }
      guard Self.owner == nil else {
        status = .failed("Another microphone is recording.")
        return
      }
      let audio = AVAudioSession.sharedInstance()
      do {
        let previous = (audio.category, audio.mode, audio.routeSharingPolicy, audio.categoryOptions)
        try audio.setCategory(.record, mode: .default)
        restoreCategory = {
          try? audio.setCategory(previous.0, mode: previous.1, policy: previous.2, options: previous.3)
        }
        try audio.setActive(true)
        Self.owner = self
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID()).wav")
        file = MicrophoneRecording(url: url)
        let recorder = try AVAudioRecorder(url: url, settings: [
          AVFormatIDKey: kAudioFormatLinearPCM,
          AVSampleRateKey: 16_000,
          AVNumberOfChannelsKey: 1,
          AVLinearPCMBitDepthKey: 16,
          AVLinearPCMIsFloatKey: false,
          AVLinearPCMIsBigEndianKey: false,
        ])
        self.recorder = recorder
        recorder.delegate = self
        let started = maximumDuration.map { recorder.record(forDuration: $0) } ?? recorder.record()
        guard started else {
          finish(.failed("The microphone could not start recording."))
          return
        }
        self.receive = receive
        status = .recording
      } catch {
        finish(.failed(error.localizedDescription))
      }
    }
  }

  func stop() {
    if status == .requestingPermission {
      cancel()
      return
    }
    guard status == .recording else {
      return
    }
    finish(.idle, deliver: true)
  }

  func cancel() {
    permissionTask?.cancel()
    permissionTask = nil
    finish(.idle)
  }

  func interrupt() {
    guard status == .recording || status == .requestingPermission else {
      return
    }
    permissionTask?.cancel()
    permissionTask = nil
    finish(.failed("Recording was interrupted. Please try again."))
  }

  private func finish(_ next: MicrophoneStatus, deliver: Bool = false) {
    let completed = file
    let action = receive
    recorder?.delegate = nil
    recorder?.stop()
    recorder = nil
    file = nil
    receive = nil
    if Self.owner === self {
      try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
      Self.owner = nil
    }
    restoreCategory?()
    restoreCategory = nil
    status = next
    if deliver, let completed, let action {
      Task {
        await action(completed)
        withExtendedLifetime(completed) {}
      }
    }
  }

  nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
    let id = ObjectIdentifier(recorder)
    Task { @MainActor in
      guard let current = self.recorder, ObjectIdentifier(current) == id else {
        return
      }
      if flag {
        finish(.idle, deliver: true)
      } else {
        finish(.failed("Recording could not be completed."))
      }
    }
  }

  nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: (any Error)?) {
    let id = ObjectIdentifier(recorder)
    let message = error?.localizedDescription ?? "Recording could not be encoded."
    Task { @MainActor in
      guard let current = self.recorder, ObjectIdentifier(current) == id else {
        return
      }
      finish(.failed(message))
    }
  }

}
