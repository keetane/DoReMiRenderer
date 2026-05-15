// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DoReMiRendererKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "DoReMiRendererKit",
            targets: ["DoReMiRendererKit"]
        ),
        .executable(
            name: "DoReMiRendererDiagnostics",
            targets: ["DoReMiRendererDiagnostics"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", .upToNextMajor(from: "0.9.0")),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "DoReMiRendererKit",
            dependencies: ["ZIPFoundation"],
            resources: [
                .process("Resources"),
            ]
        ),
        .executableTarget(
            name: "DoReMiRendererDiagnostics",
            dependencies: ["DoReMiRendererKit"]
        ),
        .testTarget(
            name: "DoReMiRendererKitTests",
            dependencies: ["DoReMiRendererKit", "ZIPFoundation"],
            exclude: ["__Snapshots__"]
        ),
        .testTarget(
            name: "DoReMiRendererDiagnosticsTests",
            dependencies: ["DoReMiRendererDiagnostics"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
