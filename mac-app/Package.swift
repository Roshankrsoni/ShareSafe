// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ShareSafe",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "ShareSafe", targets: ["ShareSafeApp"])],
    targets: [
        .target(name: "ShareSafeCore"),
        .executableTarget(name: "ShareSafeApp", dependencies: ["ShareSafeCore"]),
        .testTarget(name: "ShareSafeCoreTests", dependencies: ["ShareSafeCore"])
    ],
    swiftLanguageModes: [.v5]
)
