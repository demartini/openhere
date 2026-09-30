// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "OpenHereCore",
  platforms: [.macOS(.v15)],
  products: [
    .library(name: "OpenHereCore", targets: ["OpenHereCore"])
  ],
  targets: [
    .target(name: "OpenHereCore"),
    .testTarget(name: "OpenHereCoreTests", dependencies: ["OpenHereCore"]),
  ]
)
