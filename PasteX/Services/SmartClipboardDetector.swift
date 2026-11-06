import Foundation
import SwiftUI

struct SmartColor: Identifiable, Hashable {
    let id: String
    let source: String
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double

    var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }

    var hexRGB: String {
        String(format: "#%02X%02X%02X", redByte, greenByte, blueByte)
    }

    var hexRGBA: String {
        String(format: "#%02X%02X%02X%02X", redByte, greenByte, blueByte, alphaByte)
    }

    var rgbString: String {
        "rgb(\(redByte), \(greenByte), \(blueByte))"
    }

    var rgbaString: String {
        let alphaValue = alpha == 1 ? "1" : String(format: "%.2f", alpha)
        return "rgba(\(redByte), \(greenByte), \(blueByte), \(alphaValue))"
    }

    private var redByte: Int { byte(from: red) }
    private var greenByte: Int { byte(from: green) }
    private var blueByte: Int { byte(from: blue) }
    private var alphaByte: Int { byte(from: alpha) }

    private func byte(from component: Double) -> Int {
        min(255, max(0, Int(round(component * 255))))
    }
}

struct SmartClipboardUtility: Identifiable, Hashable {
    let id: String
    let title: String
    let value: String
    let detail: String
    let symbolName: String
}

enum SmartClipboardDetector {
    static func primaryColorCandidate(in text: String) -> SmartColor? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count <= 180 else { return nil }
        guard let firstColor = detectColors(in: trimmed).first else { return nil }

        let lowercased = trimmed.lowercased()
        let source = firstColor.source.lowercased()

        if lowercased == source || lowercased.hasPrefix(source) {
            return firstColor
        }

        let colorContextMarkers = [
            "color", "background", "border", "fill", "stroke", "tint",
            "rgb", "rgba", "hsl", "hsla", "palette", "hex"
        ]

        if colorContextMarkers.contains(where: { lowercased.contains($0) }) {
            return firstColor
        }

        return trimmed.count <= 48 ? firstColor : nil
    }

    static func detectColors(in text: String) -> [SmartColor] {
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        var colors: [SmartColor] = []
        var seenSources = Set<String>()

        for match in hexRegex.matches(in: text, range: fullRange) {
            guard
                let rawHex = capture(at: 1, in: match, text: nsText),
                let source = capture(at: 0, in: match, text: nsText),
                let color = makeHexColor(rawHex, source: source, location: match.range.location)
            else { continue }

            append(color, to: &colors, seenSources: &seenSources)
        }

        for match in rgbRegex.matches(in: text, range: fullRange) {
            guard
                let source = capture(at: 0, in: match, text: nsText),
                let red = numericCapture(at: 1, in: match, text: nsText),
                let green = numericCapture(at: 2, in: match, text: nsText),
                let blue = numericCapture(at: 3, in: match, text: nsText),
                (0...255).contains(red),
                (0...255).contains(green),
                (0...255).contains(blue)
            else { continue }

            let alpha = numericCapture(at: 4, in: match, text: nsText) ?? 1
            guard (0...1).contains(alpha) else { continue }

            let color = SmartColor(
                id: "rgb-\(match.range.location)-\(source)",
                source: source,
                red: red / 255,
                green: green / 255,
                blue: blue / 255,
                alpha: alpha
            )
            append(color, to: &colors, seenSources: &seenSources)
        }

        for match in hslRegex.matches(in: text, range: fullRange) {
            guard
                let source = capture(at: 0, in: match, text: nsText),
                let hue = numericCapture(at: 1, in: match, text: nsText),
                let saturation = numericCapture(at: 2, in: match, text: nsText),
                let lightness = numericCapture(at: 3, in: match, text: nsText),
                (0...100).contains(saturation),
                (0...100).contains(lightness)
            else { continue }

            let alpha = numericCapture(at: 4, in: match, text: nsText) ?? 1
            guard (0...1).contains(alpha) else { continue }

            let rgb = rgbFromHSL(
                hue: hue,
                saturation: saturation / 100,
                lightness: lightness / 100
            )
            let color = SmartColor(
                id: "hsl-\(match.range.location)-\(source)",
                source: source,
                red: rgb.red,
                green: rgb.green,
                blue: rgb.blue,
                alpha: alpha
            )
            append(color, to: &colors, seenSources: &seenSources)
        }

        return colors.sorted { $0.id < $1.id }
    }

    static func detectUtilities(in text: String) -> [SmartClipboardUtility] {
        var utilities: [SmartClipboardUtility] = []
        var seenValues = Set<String>()

        if let color = detectColors(in: text).first {
            appendUtility(
                SmartClipboardUtility(
                    id: "color-\(color.hexRGBA)",
                    title: "Color",
                    value: color.alpha < 1 ? color.hexRGBA : color.hexRGB,
                    detail: color.rgbString,
                    symbolName: "eyedropper.halffull"
                ),
                to: &utilities,
                seenValues: &seenValues
            )
        }

        if let uuid = firstMatch(uuidRegex, in: text) {
            appendUtility(
                SmartClipboardUtility(
                    id: "uuid-\(uuid)",
                    title: "UUID",
                    value: uuid,
                    detail: "Identifier",
                    symbolName: "number"
                ),
                to: &utilities,
                seenValues: &seenValues
            )
        }

        if let ipAddress = firstValidIPAddress(in: text) {
            appendUtility(
                SmartClipboardUtility(
                    id: "ip-\(ipAddress)",
                    title: "IP Address",
                    value: ipAddress,
                    detail: "IPv4",
                    symbolName: "network"
                ),
                to: &utilities,
                seenValues: &seenValues
            )
        }

        if let jwt = firstMatch(jwtRegex, in: text) {
            appendUtility(
                SmartClipboardUtility(
                    id: "jwt-\(jwt.prefix(18))",
                    title: "JWT",
                    value: jwt,
                    detail: "Token",
                    symbolName: "key.horizontal"
                ),
                to: &utilities,
                seenValues: &seenValues
            )
        }

        return Array(utilities.prefix(4))
    }

    private static let hexRegex = regex(#"(?i)(?<![a-f0-9])#([a-f0-9]{3,4}|[a-f0-9]{6}|[a-f0-9]{8})(?![a-f0-9])"#)
    private static let rgbRegex = regex(#"(?i)\brgba?\(\s*([0-9]{1,3}(?:\.\d+)?)\s*,\s*([0-9]{1,3}(?:\.\d+)?)\s*,\s*([0-9]{1,3}(?:\.\d+)?)(?:\s*,\s*(0|1|0?\.\d+))?\s*\)"#)
    private static let hslRegex = regex(#"(?i)\bhsla?\(\s*([0-9]{1,3}(?:\.\d+)?)\s*,\s*([0-9]{1,3}(?:\.\d+)?)%\s*,\s*([0-9]{1,3}(?:\.\d+)?)%(?:\s*,\s*(0|1|0?\.\d+))?\s*\)"#)
    private static let uuidRegex = regex(#"(?i)\b[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\b"#)
    private static let ipRegex = regex(#"\b(?:\d{1,3}\.){3}\d{1,3}\b"#)
    private static let jwtRegex = regex(#"\b[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\b"#)

    private static func regex(_ pattern: String) -> NSRegularExpression {
        do {
            return try NSRegularExpression(pattern: pattern)
        } catch {
            preconditionFailure("Invalid regular expression: \(pattern)")
        }
    }

    private static func makeHexColor(_ hex: String, source: String, location: Int) -> SmartColor? {
        let scalars = Array(hex.uppercased())
        let values = scalars.compactMap { Int(String($0), radix: 16) }
        guard values.count == scalars.count else { return nil }

        let components: (Int, Int, Int, Int)
        switch values.count {
        case 3:
            components = (values[0] * 17, values[1] * 17, values[2] * 17, 255)
        case 4:
            components = (values[0] * 17, values[1] * 17, values[2] * 17, values[3] * 17)
        case 6:
            components = (
                values[0] * 16 + values[1],
                values[2] * 16 + values[3],
                values[4] * 16 + values[5],
                255
            )
        case 8:
            components = (
                values[0] * 16 + values[1],
                values[2] * 16 + values[3],
                values[4] * 16 + values[5],
                values[6] * 16 + values[7]
            )
        default:
            return nil
        }

        return SmartColor(
            id: "hex-\(location)-\(source)",
            source: source,
            red: Double(components.0) / 255,
            green: Double(components.1) / 255,
            blue: Double(components.2) / 255,
            alpha: Double(components.3) / 255
        )
    }

    private static func rgbFromHSL(hue: Double, saturation: Double, lightness: Double) -> (red: Double, green: Double, blue: Double) {
        let normalizedHue = ((hue.truncatingRemainder(dividingBy: 360)) + 360).truncatingRemainder(dividingBy: 360)
        let chroma = (1 - abs(2 * lightness - 1)) * saturation
        let x = chroma * (1 - abs((normalizedHue / 60).truncatingRemainder(dividingBy: 2) - 1))
        let match = lightness - chroma / 2

        let rgb: (Double, Double, Double)
        switch normalizedHue {
        case 0..<60:
            rgb = (chroma, x, 0)
        case 60..<120:
            rgb = (x, chroma, 0)
        case 120..<180:
            rgb = (0, chroma, x)
        case 180..<240:
            rgb = (0, x, chroma)
        case 240..<300:
            rgb = (x, 0, chroma)
        default:
            rgb = (chroma, 0, x)
        }

        return (rgb.0 + match, rgb.1 + match, rgb.2 + match)
    }

    private static func append(_ color: SmartColor, to colors: inout [SmartColor], seenSources: inout Set<String>) {
        let key = color.source.lowercased()
        guard seenSources.insert(key).inserted else { return }
        colors.append(color)
    }

    private static func appendUtility(
        _ utility: SmartClipboardUtility,
        to utilities: inout [SmartClipboardUtility],
        seenValues: inout Set<String>
    ) {
        guard seenValues.insert(utility.value).inserted else { return }
        utilities.append(utility)
    }

    private static func firstMatch(_ regex: NSRegularExpression, in text: String) -> String? {
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        guard let match = regex.firstMatch(in: text, range: fullRange) else { return nil }
        return capture(at: 0, in: match, text: nsText)
    }

    private static func firstValidIPAddress(in text: String) -> String? {
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        let matches = ipRegex.matches(in: text, range: fullRange)

        for match in matches {
            guard let address = capture(at: 0, in: match, text: nsText) else { continue }
            let parts = address.split(separator: ".")
            guard parts.count == 4 else { continue }

            let isValid = parts.allSatisfy { part in
                guard let value = Int(part) else { return false }
                return (0...255).contains(value)
            }

            if isValid {
                return address
            }
        }

        return nil
    }

    private static func numericCapture(at index: Int, in match: NSTextCheckingResult, text: NSString) -> Double? {
        guard let value = capture(at: index, in: match, text: text) else { return nil }
        return Double(value)
    }

    private static func capture(at index: Int, in match: NSTextCheckingResult, text: NSString) -> String? {
        guard index < match.numberOfRanges else { return nil }
        let range = match.range(at: index)
        guard range.location != NSNotFound else { return nil }
        return text.substring(with: range)
    }
}
