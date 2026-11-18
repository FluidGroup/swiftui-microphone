import SwiftUI

/// Starts or stops a recording with a caller-drawn label.
public struct RecordButton<Label: View>: View {

  private let microphone: MicrophoneProxy
  private let label: (MicrophoneStatus) -> Label

  public init(
    _ microphone: MicrophoneProxy,
    @ViewBuilder label: @escaping (MicrophoneStatus) -> Label
  ) {
    self.microphone = microphone
    self.label = label
  }

  public var body: some View {
    Button {
      if microphone.status == .recording {
        microphone.stopRecording()
      } else {
        microphone.startRecording()
      }
    } label: {
      label(microphone.status)
    }
    .disabled(microphone.status != .recording && !microphone.canStartRecording)
  }

}
