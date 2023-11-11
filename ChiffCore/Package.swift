// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ChiffCore",
    defaultLocalization: "en",
    platforms: [.macOS(.v11), .iOS(.v12)],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "ChiffCore",
            targets: ["ChiffCore"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(name: "TrustKit", url: "https://github.com/datatheorem/TrustKit.git", from: "3.0.3"),
        .package(name: "PromiseKit", url: "https://github.com/mxcl/PromiseKit.git", from: "6.13.3"),
        .package(name: "DataCompression", url: "https://github.com/mw99/DataCompression.git", from: "3.6.0"),
        .package(name: "OneTimePassword", url: "https://github.com/bas-d/OneTimePassword.git", .branch("spm")),
        .package(name: "PMKFoundation", url: "https://github.com/PromiseKit/Foundation.git", from: "3.3.4"),
        .package(name: "Kronos", url: "https://github.com/MobileNativeFoundation/Kronos.git", from: "4.1.1"),
        .package(name: "Sodium", url: "https://github.com/jedisct1/swift-sodium.git", from: "0.9.1")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "ChiffCore",
            dependencies: ["TrustKit", "Sodium", "PromiseKit", "Kronos", "OneTimePassword", "DataCompression", "PMKFoundation"],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "ChiffCoreTests",
            dependencies: ["ChiffCore"],
            resources: [.process("Resources")])
    ]
)
