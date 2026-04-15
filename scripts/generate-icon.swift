#!/usr/bin/env swift
// 앱 아이콘 생성 스크립트
// macOS 앱 아이콘 규격에 맞는 .iconset 폴더를 생성한 후 iconutil로 .icns 변환

import Cocoa
import Foundation

// 아이콘 크기 목록 (파일명, 포인트 크기, 스케일)
let iconSizes: [(String, CGFloat, CGFloat)] = [
    ("icon_16x16",        16, 1),
    ("icon_16x16@2x",     16, 2),
    ("icon_32x32",        32, 1),
    ("icon_32x32@2x",     32, 2),
    ("icon_128x128",      128, 1),
    ("icon_128x128@2x",   128, 2),
    ("icon_256x256",      256, 1),
    ("icon_256x256@2x",   256, 2),
    ("icon_512x512",      512, 1),
    ("icon_512x512@2x",   512, 2),
]

func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    guard let context = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    let rect = CGRect(x: 0, y: 0, width: size, height: size)

    // --- 배경: 둥근 사각형 ---
    let cornerRadius = size * 0.22
    let bgPath = CGPath(roundedRect: rect.insetBy(dx: size * 0.02, dy: size * 0.02),
                        cornerWidth: cornerRadius, cornerHeight: cornerRadius,
                        transform: nil)

    // 그라데이션 배경 (진한 남색 → 밝은 파란색)
    context.saveGState()
    context.addPath(bgPath)
    context.clip()

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let colors = [
        CGColor(red: 0.10, green: 0.12, blue: 0.22, alpha: 1.0),  // 어두운 네이비
        CGColor(red: 0.15, green: 0.20, blue: 0.38, alpha: 1.0),  // 중간 네이비
    ]
    if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: [0.0, 1.0]) {
        context.drawLinearGradient(gradient,
                                  start: CGPoint(x: size / 2, y: size),
                                  end: CGPoint(x: size / 2, y: 0),
                                  options: [])
    }
    context.restoreGState()

    // --- 키캡 형태 ---
    let keycapInset = size * 0.15
    let keycapRect = rect.insetBy(dx: keycapInset, dy: keycapInset)
    let keycapRadius = size * 0.12
    let keycapPath = CGPath(roundedRect: keycapRect,
                            cornerWidth: keycapRadius, cornerHeight: keycapRadius,
                            transform: nil)

    // 키캡 그림자
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -size * 0.02),
                      blur: size * 0.04,
                      color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.5))
    context.setFillColor(CGColor(red: 0.18, green: 0.22, blue: 0.36, alpha: 1.0))
    context.addPath(keycapPath)
    context.fillPath()
    context.restoreGState()

    // 키캡 본체 (약간 밝은 그라데이션)
    context.saveGState()
    context.addPath(keycapPath)
    context.clip()
    let keycapColors = [
        CGColor(red: 0.25, green: 0.30, blue: 0.48, alpha: 1.0),
        CGColor(red: 0.18, green: 0.22, blue: 0.38, alpha: 1.0),
    ]
    if let keycapGradient = CGGradient(colorsSpace: colorSpace, colors: keycapColors as CFArray, locations: [0.0, 1.0]) {
        context.drawLinearGradient(keycapGradient,
                                  start: CGPoint(x: size / 2, y: keycapRect.maxY),
                                  end: CGPoint(x: size / 2, y: keycapRect.minY),
                                  options: [])
    }
    context.restoreGState()

    // 키캡 테두리 (미세한 하이라이트)
    context.saveGState()
    context.addPath(keycapPath)
    context.setStrokeColor(CGColor(red: 0.4, green: 0.45, blue: 0.6, alpha: 0.5))
    context.setLineWidth(size * 0.008)
    context.strokePath()
    context.restoreGState()

    // --- 텍스트: ⌃b (가로 배치) ---
    let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
    NSGraphicsContext.current = nsContext

    let ctrlFont = NSFont.systemFont(ofSize: size * 0.24, weight: .medium)
    let bFont = NSFont.systemFont(ofSize: size * 0.40, weight: .bold)
    let textColor = NSColor(red: 0.85, green: 0.90, blue: 1.0, alpha: 1.0)

    let ctrlStr = NSAttributedString(string: "⌃", attributes: [
        .font: ctrlFont,
        .foregroundColor: textColor,
    ])
    let bStr = NSAttributedString(string: "b", attributes: [
        .font: bFont,
        .foregroundColor: textColor,
    ])

    let gap = size * 0.01
    let totalWidth = ctrlStr.size().width + gap + bStr.size().width
    let bY = (size - bStr.size().height) / 2
    let startX = (size - totalWidth) / 2

    // ⌃의 글리프 상단을 b의 글리프 상단에 맞춤 (ascender 기준)
    let bTop = bY + bFont.ascender
    let ctrlTop = ctrlFont.ascender
    let ctrlY = bTop - ctrlTop

    ctrlStr.draw(at: NSPoint(x: startX, y: ctrlY))
    bStr.draw(at: NSPoint(x: startX + ctrlStr.size().width + gap, y: bY))

    image.unlockFocus()
    return image
}

// --- 메인 ---
let scriptDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let projectDir = scriptDir.deletingLastPathComponent()
let iconsetDir = projectDir.appendingPathComponent("Resources/AppIcon.iconset")

// iconset 디렉토리 생성
let fm = FileManager.default
try? fm.removeItem(at: iconsetDir)
try fm.createDirectory(at: iconsetDir, withIntermediateDirectories: true)

for (name, ptSize, scale) in iconSizes {
    let pixelSize = ptSize * scale
    let image = drawIcon(size: pixelSize)

    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        print("✗ \(name) 생성 실패")
        continue
    }

    let filePath = iconsetDir.appendingPathComponent("\(name).png")
    try pngData.write(to: filePath)
    print("✓ \(name).png (\(Int(pixelSize))px)")
}

print("\n아이콘셋 생성 완료: \(iconsetDir.path)")
print("iconutil로 .icns 변환 중...")

// iconutil 실행
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = [
    "-c", "icns",
    iconsetDir.path,
    "-o", projectDir.appendingPathComponent("Resources/AppIcon.icns").path
]
try process.run()
process.waitUntilExit()

if process.terminationStatus == 0 {
    print("✓ AppIcon.icns 생성 완료")
    // iconset 폴더 정리
    try? fm.removeItem(at: iconsetDir)
} else {
    print("✗ iconutil 실패 (exit: \(process.terminationStatus))")
}
