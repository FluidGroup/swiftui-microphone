// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "swiftui-microphone",
  platforms: [
    .iOS(.v18)
  ],
  products: [
    .library(name: "Microphone", targets: ["Microphone"])
  ],
  targets: [
    .target(name: "Microphone"),
    .testTarget(name: "MicrophoneTests", dependencies: ["Microphone"]),
  ],
  swiftLanguageModes: [.v6]
)
