import ProjectDescription

let project = Project(
  name: "MicrophoneDemo",
  packages: [.local(path: "..")],
  settings: .settings(base: [
    "SWIFT_VERSION": "6.0",
    "DEVELOPMENT_TEAM": .string(Environment.developmentTeam.getString(default: "")),
  ]),
  targets: [
    .target(
      name: "MicrophoneDemo",
      destinations: .iOS,
      product: .app,
      bundleId: "app.muukii.MicrophoneDemo",
      deploymentTargets: .iOS("18.0"),
      infoPlist: .extendingDefault(with: [
        "NSMicrophoneUsageDescription": "Record a short clip to try the Microphone library.",
        "UILaunchScreen": .dictionary([:]),
      ]),
      sources: ["Sources/**"],
      dependencies: [.package(product: "Microphone")]
    ),
    .target(
      name: "MicrophoneDemoTests",
      destinations: .iOS,
      product: .unitTests,
      bundleId: "app.muukii.MicrophoneDemo.Tests",
      deploymentTargets: .iOS("18.0"),
      infoPlist: .default,
      sources: ["Tests/**"],
      dependencies: [.target(name: "MicrophoneDemo")]
    ),
  ]
)
