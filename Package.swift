// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ctrl-b",
    platforms: [.macOS(.v13)],
    targets: [
        // 테스트 가능한 핵심 로직 (순수 함수, 통계)
        .target(
            name: "CtrlBCore",
            path: "Sources/CtrlBCore"
        ),
        // 메인 앱 실행 파일
        .executableTarget(
            name: "ctrl-b",
            dependencies: ["CtrlBCore"],
            path: "Sources/ctrl_b",
            linkerSettings: [
                .linkedFramework("Cocoa"),
                .linkedFramework("ServiceManagement")
            ]
        ),
        // 유닛 테스트
        .testTarget(
            name: "CtrlBTests",
            dependencies: ["CtrlBCore"],
            path: "Tests/CtrlBTests"
        )
    ]
)
