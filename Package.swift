// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CtrlB",
    defaultLocalization: "en",
    platforms: [.macOS(.v13)],
    targets: [
        // Testable core logic (pure functions, statistics)
        .target(
            name: "CtrlBCore",
            path: "Sources/CtrlBCore"
        ),
        // Main app executable
        .executableTarget(
            name: "CtrlB",
            dependencies: ["CtrlBCore"],
            path: "Sources/CtrlB",
            resources: [
                .process("Resources")
            ],
            linkerSettings: [
                .linkedFramework("Cocoa"),
                .linkedFramework("ServiceManagement")
            ]
        ),
        // Unit tests
        .testTarget(
            name: "CtrlBTests",
            dependencies: ["CtrlBCore", "CtrlB"],
            path: "Tests/CtrlBTests"
        )
    ]
)
