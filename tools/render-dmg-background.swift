import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

let output = CommandLine.arguments.dropFirst().first ?? "background.png"
let width = 720
let height = 380
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

func drawCenteredText(_ text: String, y: CGFloat, size: CGFloat, color textColor: CGColor, weight: CTFontSymbolicTraits = []) {
    let font = CTFontCreateWithName("Helvetica Neue" as CFString, size, nil)
    let attributed = NSAttributedString(string: text, attributes: [
        kCTFontAttributeName as NSAttributedString.Key: font,
        kCTForegroundColorAttributeName as NSAttributedString.Key: textColor
    ])
    let line = CTLineCreateWithAttributedString(attributed)
    let textWidth = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
    context.textPosition = CGPoint(x: (CGFloat(width) - textWidth) / 2, y: y)
    CTLineDraw(line, context)
}

context.setFillColor(color(0.035, 0.071, 0.125))
context.fill(CGRect(x: 0, y: 0, width: width, height: height))

let panel = CGPath(
    roundedRect: CGRect(x: 22, y: 20, width: 676, height: 340),
    cornerWidth: 28,
    cornerHeight: 28,
    transform: nil
)
context.addPath(panel)
context.setFillColor(color(0.075, 0.125, 0.205))
context.fillPath()

drawCenteredText("Drag to install", y: 326, size: 22, color: color(1, 1, 1))
drawCenteredText("拖到“应用程序”即可安装", y: 302, size: 14, color: color(0.78, 0.78, 0.78))

let arrow = CGMutablePath()
arrow.move(to: CGPoint(x: 306, y: 192))
arrow.addLine(to: CGPoint(x: 396, y: 192))
arrow.addLine(to: CGPoint(x: 382, y: 208))
arrow.addLine(to: CGPoint(x: 394, y: 220))
arrow.addLine(to: CGPoint(x: 430, y: 180))
arrow.addLine(to: CGPoint(x: 394, y: 140))
arrow.addLine(to: CGPoint(x: 382, y: 152))
arrow.addLine(to: CGPoint(x: 396, y: 168))
arrow.addLine(to: CGPoint(x: 306, y: 168))
arrow.closeSubpath()
context.addPath(arrow)
context.setFillColor(color(0.14, 0.75, 0.94))
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

CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else {
    fputs("Unable to save the DMG background.\n", stderr)
    exit(1)
}
