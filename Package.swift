// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Eri",
    platforms: [.macOS(.v12)],
    targets: [
        .target(
            name: "CTomlPlusPlus",
            publicHeadersPath: "include",
            cxxSettings: [
                .unsafeFlags(["-Wno-deprecated-literal-operator"]),
            ]
        ),
        .executableTarget(
            name: "Eri",
            dependencies: ["CTomlPlusPlus"]
        ),
        .testTarget(
            name: "EriTests",
            dependencies: ["Eri"]
        ),
    ],
    cxxLanguageStandard: .cxx17
)
