// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CtrlB",
    defaultLocalization: "en",
    platforms: [.macOS(.v13)],
    targets: [
        // 테스트 가능한 핵심 로직 (순수 함수, 통계)
        .target(
            name: "CtrlBCore",
            path: "Sources/CtrlBCore"
        ),
        // 메인 앱 실행 파일
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
        // 유닛 테스트
        .testTarget(
            name: "CtrlBTests",
            dependencies: ["CtrlBCore", "CtrlB"],
            path: "Tests/CtrlBTests"
        )
    ]
)
