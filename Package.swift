// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Eri",
    platforms: [.macOS(.v12)],
    dependencies: [
        .package(url: "https://github.com/LebJe/TOMLKit.git", from: "0.6.0"),
    ],
    targets: [
        .executableTarget(
            name: "Eri",
            dependencies: ["TOMLKit"]
        ),
        .testTarget(
            name: "EriTests",
            dependencies: ["Eri"]
        ),
    ]
)
