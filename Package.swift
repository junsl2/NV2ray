// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NV2ray",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "NV2ray", targets: ["NV2ray"])
    ],
    targets: [
        .executableTarget(
            name: "NV2ray",
            path: "Sources/NV2ray"
        )
    ]
)
