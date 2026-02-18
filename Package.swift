// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "appcmd",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "appcmd",
            targets: ["appcmd"]
        ),
    ],
    targets: [
        .executableTarget(
            name: "appcmd",
            path: "Sources"
        )
    ]
)

