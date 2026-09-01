// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SeifertSecurityReader",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "SeifertSecurityReader", targets: ["SeifertSecurityReader"])
    ],
    targets: [
        .executableTarget(
            name: "SeifertSecurityReader",
            resources: [.copy("Resources/Logo_seifert-it.jpg")]
        ),
        .testTarget(
            name: "SeifertSecurityReaderTests",
            dependencies: ["SeifertSecurityReader"]
        )
    ]
)
