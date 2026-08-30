import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum IconVariant: String {
    case orchard
    case dusk

    func hue(for sourceHue: CGFloat) -> CGFloat {
        switch self {
        case .orchard:
            // Red → purple, blue → green, yellow → orange.
            if sourceHue < 0.07 || sourceHue > 0.94 { return 0.76 }
            if sourceHue < 0.24 { return 0.07 }
            return 0.43
        case .dusk:
            // Red → pink, blue → teal, yellow → gold.
            if sourceHue < 0.07 || sourceHue > 0.94 { return 0.97 }
            if sourceHue < 0.24 { return 0.12 }
            return 0.50
        }
    }
}

func rgbToHSV(red: CGFloat, green: CGFloat, blue: CGFloat) -> (hue: CGFloat, saturation: CGFloat, value: CGFloat) {
    let maximum = max(red, green, blue)
    let minimum = min(red, green, blue)
    let delta = maximum - minimum
    guard delta > 0 else { return (0, 0, maximum) }

    let hue: CGFloat
    switch maximum {
    case red:
        hue = ((green - blue) / delta).truncatingRemainder(dividingBy: 6) / 6
    case green:
        hue = ((blue - red) / delta + 2) / 6
    default:
        hue = ((red - green) / delta + 4) / 6
    }
    return (hue < 0 ? hue + 1 : hue, delta / maximum, maximum)
}

func hsvToRGB(hue: CGFloat, saturation: CGFloat, value: CGFloat) -> (red: CGFloat, green: CGFloat, blue: CGFloat) {
    let h = (hue * 6).truncatingRemainder(dividingBy: 6)
    let index = Int(floor(h))
    let fraction = h - floor(h)
    let p = value * (1 - saturation)
    let q = value * (1 - saturation * fraction)
    let t = value * (1 - saturation * (1 - fraction))

    switch index {
    case 0: return (value, t, p)
    case 1: return (q, value, p)
    case 2: return (p, value, t)
    case 3: return (p, q, value)
    case 4: return (t, p, value)
    default: return (value, p, q)
    }
}

func fail(_ message: String) -> Never {
    fputs("error: \(message)\n", stderr)
    exit(1)
}

guard CommandLine.arguments.count == 4,
      let variant = IconVariant(rawValue: CommandLine.arguments[1])
else {
    fail("usage: generate-app-icons.swift <orchard|dusk> <source.png> <destination.png>")
}

let sourceURL = URL(fileURLWithPath: CommandLine.arguments[2])
let destinationURL = URL(fileURLWithPath: CommandLine.arguments[3])
guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
      let sourceImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
else {
    fail("could not read \(sourceURL.path)")
}

let width = sourceImage.width
let height = sourceImage.height
let colorSpace = CGColorSpaceCreateDeviceRGB()
var pixels = [UInt8](repeating: 0, count: width * height * 4)
guard let context = CGContext(
    data: &pixels,
    width: width,
    height: height,
    bitsPerComponent: 8,
    bytesPerRow: width * 4,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    fail("could not create an RGBA bitmap context")
}

context.draw(sourceImage, in: CGRect(x: 0, y: 0, width: width, height: height))

for offset in stride(from: 0, to: pixels.count, by: 4) {
    let red = CGFloat(pixels[offset]) / 255
    let green = CGFloat(pixels[offset + 1]) / 255
    let blue = CGFloat(pixels[offset + 2]) / 255
    let hsv = rgbToHSV(red: red, green: green, blue: blue)

    // The original icon's charcoal background and shadows are intentionally
    // left untouched. Only bright, saturated shape pixels are remapped.
    guard hsv.saturation > 0.25, hsv.value > 0.32 else { continue }

    let replacement = hsvToRGB(
        hue: variant.hue(for: hsv.hue),
        saturation: hsv.saturation,
        value: hsv.value
    )
    pixels[offset] = UInt8((replacement.red * 255).rounded())
    pixels[offset + 1] = UInt8((replacement.green * 255).rounded())
    pixels[offset + 2] = UInt8((replacement.blue * 255).rounded())
}

guard let image = context.makeImage() else {
    fail("could not create the \(variant.rawValue) icon")
}
try FileManager.default.createDirectory(
    at: destinationURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)
guard let destination = CGImageDestinationCreateWithURL(
    destinationURL as CFURL,
    UTType.png.identifier as CFString,
    1,
    nil
) else {
    fail("could not create \(destinationURL.path)")
}
CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else {
    fail("could not write \(destinationURL.path)")
}
