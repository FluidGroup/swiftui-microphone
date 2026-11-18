# swiftui-microphone

`Microphone` owns a recording session and leaves the controls to you. Like
[`Camera`](https://github.com/FluidGroup/swiftui-camera), it gives its content a
proxy and delivers each finished capture through a view modifier.

```swift
import Microphone
import SwiftUI

struct Recorder: View {
  @State private var lastRecording: MicrophoneRecording?

  var body: some View {
    Microphone(maximumDuration: 10) { mic in
      VStack {
        RecordButton(mic) { status in
          Text(status == .recording ? "Stop" : "Record")
        }

        if mic.status == .accessDenied {
          Text("Allow microphone access in Settings to record.")
        }
      }
    }
    .onAudioCapture { recording in
      lastRecording = recording
    }
  }
}
```

Add the `Microphone` product to an iOS 18+ app and set `NSMicrophoneUsageDescription`.
Access is requested on the first recording attempt, not when the view appears. No capture
handler (or `.onAudioCapture(isEnabled: false)`) means new recordings cannot start.

For custom controls, read `mic.status` and call `startRecording()`, `stopRecording()`,
or `cancelRecording()` on the proxy. Stopping or reaching `maximumDuration` delivers
one mono, 16 kHz, 16-bit PCM WAV on the main actor. An unfinished recording is discarded
on cancellation, interruption, backgrounding, or when the container leaves the screen.

The file at `recording.url` is valid for the duration of the async capture action.
Retain the `MicrophoneRecording` to keep the temporary file longer, or copy it for permanent storage.
Recording temporarily uses the app's shared audio session; coordinate with any other audio in your app.

To try the recorder or run the optional live-capture test, run
`mise trust && mise install && mise run demo`. Open `Development/MicrophoneDemo.xcworkspace`
and run the app on an iPhone or a simulator with audio input. Tap Record and grant microphone
access before testing the `MicrophoneDemo` scheme. Package unit tests do not require a microphone.
