import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

let output = CommandLine.arguments.dropFirst().first ?? "background.png"
let logicalWidth: CGFloat = 720
let logicalHeight: CGFloat = 420
let retinaScale: CGFloat = 2
let width = Int(logicalWidth * retinaScale)
let height = Int(logicalHeight * retinaScale)
let colorSpace = CGColorSpaceCreateDeviceRGB()

guard let context = CGContext(
    data: nil,
    width: width,
    height: height,
    bitsPerComponent: 8,
    bytesPerRow: width * 4,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    fputs("Unable to create the DMG background canvas.\n", stderr)
    exit(1)
}

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(red: red, green: green, blue: blue, alpha: alpha)
}

func drawCenteredText(_ text: String, y: CGFloat, size: CGFloat, color textColor: CGColor, fontName: String) {
    let font = CTFontCreateWithName(fontName as CFString, size, nil)
    let attributed = NSAttributedString(string: text, attributes: [
        kCTFontAttributeName as NSAttributedString.Key: font,
        kCTForegroundColorAttributeName as NSAttributedString.Key: textColor
    ])
    let line = CTLineCreateWithAttributedString(attributed)
    let textWidth = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
    context.textPosition = CGPoint(x: (logicalWidth - textWidth) / 2, y: y)
    CTLineDraw(line, context)
}

context.scaleBy(x: retinaScale, y: retinaScale)
context.setFillColor(color(1, 1, 1))
context.fill(CGRect(x: 0, y: 0, width: logicalWidth, height: logicalHeight))

let panel = CGPath(
    roundedRect: CGRect(x: 22, y: 20, width: 676, height: 380),
    cornerWidth: 28,
    cornerHeight: 28,
    transform: nil
)
context.addPath(panel)
context.setFillColor(color(0.985, 0.99, 0.998))
context.fillPath()
context.addPath(panel)
context.setStrokeColor(color(0.84, 0.87, 0.92))
context.setLineWidth(2)
context.strokePath()

drawCenteredText("Drag to Applications", y: 330, size: 30, color: color(0.08, 0.11, 0.16), fontName: "HelveticaNeue-Bold")
drawCenteredText("将 Lights.app 拖到“应用程序”即可安装", y: 296, size: 18, color: color(0.25, 0.30, 0.38), fontName: "PingFangSC-Regular")

let arrow = CGMutablePath()
arrow.move(to: CGPoint(x: 414, y: 182))
arrow.addLine(to: CGPoint(x: 324, y: 182))
arrow.addLine(to: CGPoint(x: 338, y: 198))
arrow.addLine(to: CGPoint(x: 326, y: 210))
arrow.addLine(to: CGPoint(x: 290, y: 170))
arrow.addLine(to: CGPoint(x: 326, y: 130))
arrow.addLine(to: CGPoint(x: 338, y: 142))
arrow.addLine(to: CGPoint(x: 324, y: 158))
arrow.addLine(to: CGPoint(x: 414, y: 158))
arrow.closeSubpath()
context.addPath(arrow)
context.setFillColor(color(0.08, 0.10, 0.14))
context.fillPath()

guard let image = context.makeImage(),
      let destination = CGImageDestinationCreateWithURL(
        URL(fileURLWithPath: output) as CFURL,
        UTType.png.identifier as CFString,
        1,
        nil
      ) else {
    fputs("Unable to encode the DMG background.\n", stderr)
    exit(1)
}

CGImageDestinationAddImage(destination, image, [
    kCGImagePropertyDPIWidth: 144,
    kCGImagePropertyDPIHeight: 144
] as CFDictionary)
guard CGImageDestinationFinalize(destination) else {
    fputs("Unable to save the DMG background.\n", stderr)
    exit(1)
}
