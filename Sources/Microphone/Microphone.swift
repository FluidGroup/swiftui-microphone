import AVFAudio
import Combine
import Foundation
import SwiftUI

/// Hosts microphone controls without drawing any UI or requesting access until a recording starts.
public struct Microphone<Content: View>: View {

  @Environment(\.scenePhase) private var scenePhase
  @State private var session = RecordingSession()

  private let maximumDuration: TimeInterval?
  private let content: (MicrophoneProxy) -> Content
  private var capture: (@MainActor (MicrophoneRecording) async -> Void)?

  public init(
    maximumDuration: TimeInterval? = nil,
    @ViewBuilder content: @escaping (MicrophoneProxy) -> Content
  ) {
    self.maximumDuration = maximumDuration
    self.content = content
  }

  /// Enables new recordings. A recording already in progress keeps its original completion action.
  public func onAudioCapture(
    isEnabled: Bool = true,
    perform action: @escaping @MainActor (MicrophoneRecording) async -> Void
  ) -> Self {
    var microphone = self
    if isEnabled {
      microphone.capture = action
    } else {
      microphone.capture = nil
    }
    return microphone
  }

  public var body: some View {
    ZStack {
      content(.init(session: session, maximumDuration: maximumDuration, capture: capture))
    }
    .onAppear { session.isVisible = true }
    .onDisappear {
      session.isVisible = false
      session.cancel()
    }
    .onChange(of: scenePhase) { _, phase in
      if phase == .background {
        session.cancel()
      }
    }
    .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)) { note in
      if note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt == AVAudioSession.InterruptionType.began.rawValue {
        session.interrupt()
      }
    }
    .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.mediaServicesWereResetNotification)) { _ in
      session.interrupt()
    }
  }

}

/// Read and operate the microphone inside the `Microphone` that supplied this proxy.
@MainActor
public struct MicrophoneProxy {

  let session: RecordingSession
  let maximumDuration: TimeInterval?
  let capture: (@MainActor (MicrophoneRecording) async -> Void)?

  public var status: MicrophoneStatus {
    session.status
  }

  public var canStartRecording: Bool {
    session.isVisible && capture != nil && status != .requestingPermission && status != .recording
  }

  public func startRecording() {
    guard canStartRecording, let capture else {
      return
    }
    session.start(maximumDuration: maximumDuration, receive: capture)
  }

  public func stopRecording() {
    session.stop()
  }

  public func cancelRecording() {
    session.cancel()
  }

}

public enum MicrophoneStatus: Equatable, Sendable {

  case idle
  case requestingPermission
  case recording
  case accessDenied
  case failed(String)

}

/// Retain the recording while reading its mono 16 kHz PCM WAV, or copy it to keep it.
public final class MicrophoneRecording: Sendable {

  public let url: URL

  init(url: URL) {
    self.url = url
  }

  deinit {
    try? FileManager.default.removeItem(at: url)
  }

}
