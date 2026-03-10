// swift-tools-version:5.10
import PackageDescription

let package = Package(
  name: "SagaPathKit",
  products: [
    .library(name: "SagaPathKit", targets: ["SagaPathKit"]),
  ],
  targets: [
    .target(name: "SagaPathKit", dependencies: [], path: "Sources"),
    .testTarget(name: "SagaPathKitTests", dependencies: ["SagaPathKit"], path: "Tests/SagaPathKitTests", exclude: ["Fixtures"]),
  ]
)
