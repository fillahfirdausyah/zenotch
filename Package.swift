// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Zenotch",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Zenotch", targets: ["Zenotch"]),
    ],
    targets: [
        .target(name: "ZenotchKit"),
        .executableTarget(name: "Zenotch", dependencies: ["ZenotchKit"]),
        .testTarget(name: "ZenotchKitTests", dependencies: ["ZenotchKit"]),
    ],
    swiftLanguageModes: [.v5]
)
