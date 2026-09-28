// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "WemoControl",
    platforms: [.macOS(.v12)],
    targets: [
        .executableTarget(
            name: "WemoControl",
            path: "Sources/WemoControl"
        )
    ]
)
