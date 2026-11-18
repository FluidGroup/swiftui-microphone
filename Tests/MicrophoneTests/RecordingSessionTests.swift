import Foundation
import Testing
@testable import Microphone

@MainActor
struct RecordingSessionTests {

  @Test func disappearingWhileRequestingPermissionDiscardsTheStart() async {
    var answer: CheckedContinuation<Bool, Never>?
    let session = RecordingSession {
      await withCheckedContinuation { answer = $0 }
    }
    session.isVisible = true
    session.start(maximumDuration: nil) { _ in Issue.record("Unexpected recording") }
    let deadline = ContinuousClock.now + .seconds(2)
    while answer == nil && ContinuousClock.now < deadline {
      await Task.yield()
    }
    #expect(answer != nil)
    session.isVisible = false
    session.cancel()
    answer?.resume(returning: true)
    await Task.yield()
    #expect(session.status == .idle)
  }

  @Test func denialCanBeRetried() async {
    var requests = 0
    let session = RecordingSession {
      requests += 1
      return false
    }
    session.isVisible = true
    for _ in 0..<2 {
      session.start(maximumDuration: nil) { _ in Issue.record("Unexpected recording") }
      let deadline = ContinuousClock.now + .seconds(2)
      while session.status == .requestingPermission && ContinuousClock.now < deadline {
        await Task.yield()
      }
      #expect(session.status == .accessDenied)
    }
    #expect(requests == 2)
  }

  @Test func startingRequiresAVisibleMicrophoneAndAnEnabledCaptureHandler() {
    let session = RecordingSession {
      Issue.record("Unexpected permission request")
      return false
    }
    let enabled = MicrophoneProxy(session: session, maximumDuration: nil) { _ in }
    let disabled = MicrophoneProxy(session: session, maximumDuration: nil, capture: nil)

    enabled.startRecording()
    #expect(!enabled.canStartRecording)
    #expect(enabled.status == .idle)

    session.isVisible = true
    disabled.startRecording()
    #expect(!disabled.canStartRecording)
    #expect(disabled.status == .idle)
    #expect(enabled.canStartRecording)
  }

  @Test func invalidDurationFailsBeforeRequestingPermission() {
    let session = RecordingSession {
      Issue.record("Unexpected permission request")
      return false
    }
    session.isVisible = true
    let mic = MicrophoneProxy(session: session, maximumDuration: .infinity) { _ in }
    mic.startRecording()

    guard case .failed = mic.status else {
      Issue.record("Expected an invalid-duration failure")
      return
    }
  }

  @Test func recordingOwnsItsTemporaryFile() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try Data([1]).write(to: url)
    do {
      let recording = MicrophoneRecording(url: url)
      #expect(try Data(contentsOf: recording.url) == Data([1]))
    }
    #expect(!FileManager.default.fileExists(atPath: url.path))
  }

}
