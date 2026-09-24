import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let source = root.appendingPathComponent("assets/images/kloudy_app_icon.svg")
guard let vector = NSImage(contentsOf: source) else {
    fatalError("Could not load assets/images/kloudy_app_icon.svg")
}

func render(_ size: Int, to destination: URL) throws {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        fatalError("Could not create a (size)px bitmap")
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    vector.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
    NSGraphicsContext.current?.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()

    let png = bitmap.representation(using: .png, properties: [:])!
    try FileManager.default.createDirectory(
        at: destination.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try png.write(to: destination)
}

let iosIcons: [(String, Int)] = [
    ("Icon-App-20x20@2x.png", 40), ("Icon-App-20x20@3x.png", 60),
    ("Icon-App-29x29@1x.png", 29), ("Icon-App-29x29@2x.png", 58),
    ("Icon-App-29x29@3x.png", 87), ("Icon-App-40x40@2x.png", 80),
    ("Icon-App-40x40@3x.png", 120), ("Icon-App-60x60@2x.png", 120),
    ("Icon-App-60x60@3x.png", 180), ("Icon-App-20x20@1x.png", 20),
    ("Icon-App-20x20@2x-ipad.png", 40), ("Icon-App-29x29@1x-ipad.png", 29),
    ("Icon-App-29x29@2x-ipad.png", 58), ("Icon-App-40x40@1x.png", 40),
    ("Icon-App-40x40@2x-ipad.png", 80), ("Icon-App-76x76@1x.png", 76),
    ("Icon-App-76x76@2x.png", 152), ("Icon-App-83.5x83.5@2x.png", 167),
    ("Icon-App-1024x1024@1x.png", 1024),
]

let iosDirectory = root.appendingPathComponent("ios/Runner/Assets.xcassets/AppIcon.appiconset")
for (filename, size) in iosIcons {
    let actualFilename: String
    switch filename {
    case "Icon-App-20x20@2x-ipad.png": actualFilename = "Icon-App-20x20@2x.png"
    case "Icon-App-29x29@1x-ipad.png": actualFilename = "Icon-App-29x29@1x.png"
    case "Icon-App-29x29@2x-ipad.png": actualFilename = "Icon-App-29x29@2x.png"
    case "Icon-App-40x40@1x.png": actualFilename = "Icon-App-40x40@1x.png"
    case "Icon-App-40x40@2x-ipad.png": actualFilename = "Icon-App-40x40@2x.png"
    default: actualFilename = filename
    }
    try render(size, to: iosDirectory.appendingPathComponent(actualFilename))
}

let androidIcons: [(String, Int)] = [
    ("mipmap-mdpi/ic_launcher.png", 48),
    ("mipmap-hdpi/ic_launcher.png", 72),
    ("mipmap-xhdpi/ic_launcher.png", 96),
    ("mipmap-xxhdpi/ic_launcher.png", 144),
    ("mipmap-xxxhdpi/ic_launcher.png", 192),
]
let androidDirectory = root.appendingPathComponent("android/app/src/main/res")
for (filename, size) in androidIcons {
    try render(size, to: androidDirectory.appendingPathComponent(filename))
}

print("Rendered iOS and Android Kloudy app icons from kloudy_app_icon.svg")
