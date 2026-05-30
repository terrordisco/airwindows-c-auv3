// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AirwindowsUI",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "AirwindowsUI",
            targets: ["AirwindowsUI"]
        )
    ],
    targets: [
        .target(
            name: "AirwindowsUI"
        )
    ]
)
