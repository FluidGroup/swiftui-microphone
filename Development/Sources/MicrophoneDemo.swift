import Microphone
import SwiftUI

@main
struct MicrophoneDemo: App {

  var body: some Scene {
    WindowGroup {
      Recorder()
    }
  }

}

private struct Recorder: View {

  @State private var clip: MicrophoneRecording?

  var body: some View {
    Microphone(maximumDuration: 10) { mic in
      VStack(spacing: 16) {
        RecordButton(mic) { status in
          if status == .recording {
            Label("Stop", systemImage: "stop.fill")
          } else {
            Label("Record", systemImage: "mic.fill")
          }
        }
        .buttonStyle(.borderedProminent)

        switch mic.status {
        case .requestingPermission:
          ProgressView("Requesting microphone access")
        case .accessDenied:
          Text("Allow microphone access in Settings to record.")
        case .failed(let message):
          Text(message)
        case .recording:
          Text("Recording • 10 seconds maximum")
        case .idle:
          if let clip {
            ShareLink("Share last recording", item: clip.url)
          }
        }
      }
      .padding()
    }
    .onAudioCapture { clip = $0 }
  }

}
