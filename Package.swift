// swift-tools-version: 5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-book-converter",
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "swift-book-converter",
            targets: ["BookConverter"]),
        .executable(
            name: "BookConverterCLI",
            targets: ["BookConverterCLI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.1.3"),
        .package(url: "https://github.com/apple/swift-markdown.git", branch: "main"),
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.4.3")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "BookConverter",
            dependencies: [ "SwiftSoup",
                .product(name: "Markdown", package: "swift-markdown")
            ]),
        .target(name: "Documentation"),
        .testTarget(
            name: "BookConverterTests",
            dependencies: ["BookConverter"],
            resources: [.copy("SwiftBook")]),
        .executableTarget(
            name: "BookConverterCLI",
            dependencies: [
                "BookConverter",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]),
        
    ]
)
