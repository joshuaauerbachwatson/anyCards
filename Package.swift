// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AnyCards",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "AnyCards",
            targets: ["anyCards"]),
    ],
    dependencies: [
        .package(url: "https://github.com/joshuaauerbachwatson/AuerbachLook.git", branch: "main"),
        .package(url: "https://github.com/joshuaauerbachwatson/unigame.git", branch: "main"),
        .package(url: "https://github.com/SomeRandomiOSDev/CBORCoding", .upToNextMajor(from: "1.4.0")),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "anyCards",
            dependencies: [
                .product(name: "AuerbachLook", package: "auerbachlook"),
                .product(name: "unigame", package: "unigame"),
                .product(name: "CBORCoding", package: "CBORCoding"),
            ],
            resources: [.process("Resources")],
        ),
    ],
    swiftLanguageModes: [.v5]
)
