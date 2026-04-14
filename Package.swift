// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ctrl-b-helper",
    platforms: [.macOS(.v13)],
    targets: [
        // 테스트 가능한 핵심 로직 (순수 함수, 통계)
        .target(
            name: "CtrlBHelperCore",
            path: "Sources/CtrlBHelperCore"
        ),
        // 메인 앱 실행 파일
        .executableTarget(
            name: "ctrl-b-helper",
            dependencies: ["CtrlBHelperCore"],
            path: "Sources/ctrl_b_helper",
            linkerSettings: [
                .linkedFramework("Cocoa"),
                .linkedFramework("ServiceManagement"),
            ]
        ),
        // 유닛 테스트
        .testTarget(
            name: "CtrlBHelperTests",
            dependencies: ["CtrlBHelperCore"],
            path: "Tests/CtrlBHelperTests"
        ),
    ]
)
