// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "inky",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        .executable(name: "inky", targets: ["inky"])
    ],
    dependencies: [
        .package(url: "https://github.com/johnsundell/ink.git", from: "0.1.0"),
        .package(url: "https://github.com/apple/swift-package-manager.git", from: "0.1.0"),
    ],
    targets: [
        .target(
            name: "inky",
            dependencies: ["SwiftPM", "Ink"])
        ]
)
