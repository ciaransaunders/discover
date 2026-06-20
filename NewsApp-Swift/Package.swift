// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "NewsApp",
  defaultLocalization: "en",
  platforms: [
    .iOS(.v17),
    .macOS(.v14),
  ],
  products: [
    .iOSApplication(
      name: "NewsApp",
      targets: ["NewsAppModule"],
      bundleIdentifier: "com.discover.NewsApp",
      teamIdentifier: "",
      displayVersion: "1.0",
      bundleVersion: "1",
      iconAssetName: "AppIcon",
      accentColorAssetName: "AccentColor",
      supportedDeviceFamilies: [
        .pad,
        .phone,
      ],
      supportedInterfaceOrientations: [
        .portrait,
        .landscapeRight,
        .landscapeLeft,
        .portraitUpsideDown(.when(deviceFamilies: [.pad])),
      ]
    )
  ],
  targets: [
    .executableTarget(
      name: "NewsAppModule",
      path: ".",
      sources: [
        "App",
        "Core",
        "Features",
        "Resources",
      ]
    ),
    .testTarget(
      name: "NewsAppTests",
      dependencies: ["NewsAppModule"],
      path: "Tests/NewsAppTests"
    ),
  ]
)
