// swift-tools-version:5.10
import PackageDescription

let package = Package(
  name: "PathKit",
  products: [
    .library(name: "PathKit", targets: ["PathKit"]),
  ],
  targets: [
    .target(name: "PathKit", dependencies: [], path: "Sources"),
    .testTarget(name: "PathKitTests", dependencies: ["PathKit"], path: "Tests/PathKitTests", exclude: ["Fixtures"]),
  ]
)
