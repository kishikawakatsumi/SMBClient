// swift-tools-version: 5.5

import PackageDescription

let package = Package(
  name: "SMBClient",
  platforms: [
    .macOS(.v10_15),
    .iOS(.v13)
  ],
  products: [
    .library(
      name: "SMBClient",
      targets: ["SMBClient"]
    ),
  ],
  targets: [
    .target(
      name: "SMBClient"
    ),
    .testTarget(
      name: "SMBClientTests",
      dependencies: ["SMBClient"],
      resources: [.copy("Fixtures")]
    ),
  ]
)
