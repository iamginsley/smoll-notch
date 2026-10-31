import AppKit
import CoreImage
import SwiftUI

// The island always sits on the black notch, in light and dark mode alike, so its colors are fixed:
// white labels on black (21:1), secondary at 70 % (>9:1). Everything else (settings, menu) uses system colors.

extension Color {
    static let island = Color.black
    static let islandPrimary = Color.white
    static let islandSecondary = Color.white.opacity(0.7)
    static let islandTrack = Color.white.opacity(0.2)
}

extension Font {
    static let islandTitle = Font.system(.title3, weight: .semibold)
    static let islandSubtitle = Font.system(.body, weight: .medium)
    static let islandTime = Font.system(.caption, weight: .medium).monospacedDigit()
}

enum Theme {
    static let minTapSize: CGFloat = 44
    static let artworkCornerRadius: CGFloat = 16
}

/// The signature element: the equalizer takes on the cover's color.
enum ArtworkTint {
    /// Average color of the artwork, brightened until it reads on black.
    static func color(for data: Data) -> Color? {
        guard let image = CIImage(data: data) else { return nil }
        let filter = CIFilter(name: "CIAreaAverage", parameters: [
            kCIInputImageKey: image,
            kCIInputExtentKey: CIVector(cgRect: image.extent),
        ])
        guard let output = filter?.outputImage else { return nil }
        var pixel = [UInt8](repeating: 0, count: 4)
        CIContext(options: [.workingColorSpace: NSNull()]).render(
            output, toBitmap: &pixel, rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil
        )
        let rgb = readable(red: Double(pixel[0]) / 255, green: Double(pixel[1]) / 255, blue: Double(pixel[2]) / 255)
        return Color(red: rgb.red, green: rgb.green, blue: rgb.blue)
    }

    /// Boosts saturation a little and raises brightness until the contrast on black is at least 4.5:1.
    static func readable(red: Double, green: Double, blue: Double) -> (red: Double, green: Double, blue: Double) {
        let color = NSColor(srgbRed: red, green: green, blue: blue, alpha: 1)
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        saturation = min(saturation * 1.3, 0.85)
        brightness = max(brightness, 0.6)

        var result = rgb(hue: hue, saturation: saturation, brightness: brightness)
        while contrastOnBlack(result) < 4.5, brightness < 1 || saturation > 0 {
            if brightness < 1 { brightness = min(brightness + 0.05, 1) } else { saturation = max(saturation - 0.05, 0) }
            result = rgb(hue: hue, saturation: saturation, brightness: brightness)
        }
        return result
    }

    static func contrastOnBlack(_ color: (red: Double, green: Double, blue: Double)) -> Double {
        func linear(_ c: Double) -> Double { c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        let luminance = 0.2126 * linear(color.red) + 0.7152 * linear(color.green) + 0.0722 * linear(color.blue)
        return (luminance + 0.05) / 0.05
    }

    private static func rgb(hue: CGFloat, saturation: CGFloat, brightness: CGFloat) -> (red: Double, green: Double, blue: Double) {
        let color = NSColor(hue: hue, saturation: saturation, brightness: brightness, alpha: 1).usingColorSpace(.sRGB)!
        return (Double(color.redComponent), Double(color.greenComponent), Double(color.blueComponent))
    }
}
