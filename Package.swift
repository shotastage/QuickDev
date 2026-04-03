// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "QuickDev",
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "QuickDev",
            targets: ["QuickDev"]
        ),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "QuickDev"
        ),
        .testTarget(
            name: "QuickDevTests",
            dependencies: ["QuickDev"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
