import AVFAudio
import Foundation
import XCTest
@testable import Microphone

@MainActor
final class LiveCaptureTests: XCTestCase {

  func testManualStopAndDurationLimitEachDeliverOneWAV() async throws {
    try XCTSkipUnless(
      AVAudioApplication.shared.recordPermission == .granted,
      "Live capture needs an audio input and microphone access for the test runner."
    )

    let session = RecordingSession()
    session.isVisible = true
    defer { session.cancel() }

    for duration: TimeInterval? in [nil, 0.4] {
      var results: [MicrophoneRecording] = []
      let mic = MicrophoneProxy(session: session, maximumDuration: duration) {
        results.append($0)
      }
      mic.startRecording()
      let deadline = ContinuousClock.now + .seconds(5)
      while mic.status == .requestingPermission && ContinuousClock.now < deadline {
        try await Task.sleep(for: .milliseconds(10))
      }
      XCTAssertEqual(mic.status, .recording)
      if duration == nil {
        try await Task.sleep(for: .milliseconds(250))
        mic.stopRecording()
      }
      while results.isEmpty && ContinuousClock.now < deadline {
        try await Task.sleep(for: .milliseconds(10))
      }
      mic.stopRecording()
      XCTAssertEqual(mic.status, .idle)
      XCTAssertEqual(results.count, 1)
      let recording = try XCTUnwrap(results.first)
      let audio = try AVAudioFile(forReading: recording.url)
      XCTAssertEqual(audio.fileFormat.sampleRate, 16_000)
      XCTAssertEqual(audio.fileFormat.channelCount, 1)
      XCTAssertGreaterThan(audio.length, 0)
    }
  }

}
