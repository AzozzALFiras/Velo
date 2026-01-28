//
//  ANSIParser.swift
//  Velo
//
//  AI-Powered Terminal - ANSI Escape Code Parser
//

import SwiftUI

// MARK: - ANSI Parser
/// Parses ANSI escape sequences and converts them to attributed strings
final class ANSIParser {
    
    // MARK: - Singleton
    static let shared = ANSIParser()
    
    // MARK: - ANSI Colors (Standard 16)
    private let standardColors: [Int: Color] = [
        30: Color(hex: "1C1C1C"),  // Black
        31: Color(hex: "FF6B6B"),  // Red
        32: Color(hex: "00FF88"),  // Green
        33: Color(hex: "FFD60A"),  // Yellow
        34: Color(hex: "6B9BFF"),  // Blue
        35: Color(hex: "BF40BF"),  // Magenta
        36: Color(hex: "00F5FF"),  // Cyan
        37: Color(hex: "E5E5E5"),  // White
        90: Color(hex: "666666"),  // Bright Black (Gray)
        91: Color(hex: "FF8A8A"),  // Bright Red
        92: Color(hex: "88FFA8"),  // Bright Green
        93: Color(hex: "FFEA70"),  // Bright Yellow
        94: Color(hex: "8AB4FF"),  // Bright Blue
        95: Color(hex: "D070D0"),  // Bright Magenta
        96: Color(hex: "70FFFF"),  // Bright Cyan
        97: Color(hex: "FFFFFF"),  // Bright White
    ]
    
    private let standardBackgrounds: [Int: Color] = [
        40: Color(hex: "1C1C1C"),
        41: Color(hex: "FF6B6B"),
        42: Color(hex: "00FF88"),
        43: Color(hex: "FFD60A"),
        44: Color(hex: "6B9BFF"),
        45: Color(hex: "BF40BF"),
        46: Color(hex: "00F5FF"),
        47: Color(hex: "E5E5E5"),
        100: Color(hex: "666666"),
        101: Color(hex: "FF8A8A"),
        102: Color(hex: "88FFA8"),
        103: Color(hex: "FFEA70"),
        104: Color(hex: "8AB4FF"),
        105: Color(hex: "D070D0"),
        106: Color(hex: "70FFFF"),
        107: Color(hex: "FFFFFF"),
    ]
    
    // MARK: - Parse ANSI String
    /// Parse a string with ANSI codes into an AttributedString
    func parse(_ input: String) -> AttributedString {
        var result = AttributedString()
        var currentAttributes = TextAttributes()
        
        // Regex to match ANSI escape sequences
        // CSI: \x1B\[[0-?]*[ -/]*[@-~]
        // OSC: \x1B\][0-9]*;.*?(?:\x07|\x1B\\)
        let ansiPattern = "(\\x1B\\[[0-?]*[ -/]*[@-~])|(\\x1B\\][0-9]*;.*?(?:\\x07|\\x1B\\\\))"
        guard let regex = try? NSRegularExpression(pattern: ansiPattern, options: []) else {
            return AttributedString(input)
        }
        
        let nsString = input as NSString
        var lastEnd = 0
        
        let matches = regex.matches(in: input, range: NSRange(location: 0, length: nsString.length))
        
        for match in matches {
            // Add text before this escape sequence
            if match.range.location > lastEnd {
                let textRange = NSRange(location: lastEnd, length: match.range.location - lastEnd)
                let text = nsString.substring(with: textRange)
                var attributed = AttributedString(text)
                applyAttributes(&attributed, attributes: currentAttributes)
                result.append(attributed)
            }
            
            // Parse the escape codes - ONLY if it is an SGR code (ends in 'm')
            let fullMatchString = nsString.substring(with: match.range)
            if fullMatchString.hasSuffix("m") {
                // Extract parameters inside CSI ... m
                // Remove prefix CSI (ESC [) and suffix m
                let parameters = fullMatchString.dropFirst(2).dropLast()
                let codes = parameters.split(separator: ";").compactMap { Int($0) }
                updateAttributes(&currentAttributes, with: codes)
            }
            
            lastEnd = match.range.location + match.range.length
        }
        
        // Add remaining text
        if lastEnd < nsString.length {
            let text = nsString.substring(from: lastEnd)
            var attributed = AttributedString(text)
            applyAttributes(&attributed, attributes: currentAttributes)
            result.append(attributed)
        }
        
        if result.characters.isEmpty {
            return AttributedString(input)
        }
        
        return result
    }
    
    // MARK: - Strip ANSI Codes
    /// Remove all ANSI escape sequences from a string
    func stripANSI(_ input: String) -> String {
        // Matches CSI sequences (ESC [ ...) and OSC sequences (ESC ] ...)
        let pattern = "(\\x1B\\[[0-?]*[ -/]*[@-~])|(\\x1B\\][0-9]*;.*?(?:\\x07|\\x1B\\\\))"
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return input
        }
        let range = NSRange(input.startIndex..., in: input)
        return regex.stringByReplacingMatches(in: input, range: range, withTemplate: "")
    }
    
    // MARK: - Private Helpers
    private func updateAttributes(_ attributes: inout TextAttributes, with codes: [Int]) {
        var i = 0
        while i < codes.count {
            let code = codes[i]
            
            switch code {
            case 0: // Reset
                attributes = TextAttributes()
            case 1: // Bold
                attributes.isBold = true
            case 2: // Dim
                attributes.isDim = true
            case 3: // Italic
                attributes.isItalic = true
            case 4: // Underline
                attributes.isUnderlined = true
            case 7: // Inverse
                attributes.isInverse = true
            case 9: // Strikethrough
                attributes.isStrikethrough = true
            case 22: // Reset bold/dim
                attributes.isBold = false
                attributes.isDim = false
            case 23: // Reset italic
                attributes.isItalic = false
            case 24: // Reset underline
                attributes.isUnderlined = false
            case 27: // Reset inverse
                attributes.isInverse = false
            case 29: // Reset strikethrough
                attributes.isStrikethrough = false
            case 30...37, 90...97: // Foreground colors
                attributes.foregroundColor = standardColors[code]
            case 38: // Extended foreground
                if i + 1 < codes.count && codes[i + 1] == 5 && i + 2 < codes.count {
                    // 256-color mode
                    attributes.foregroundColor = color256(codes[i + 2])
                    i += 2
                } else if i + 1 < codes.count && codes[i + 1] == 2 && i + 4 < codes.count {
                    // RGB mode
                    attributes.foregroundColor = Color(
                        red: Double(codes[i + 2]) / 255.0,
                        green: Double(codes[i + 3]) / 255.0,
                        blue: Double(codes[i + 4]) / 255.0
                    )
                    i += 4
                }
            case 39: // Default foreground
                attributes.foregroundColor = nil
            case 40...47, 100...107: // Background colors
                attributes.backgroundColor = standardBackgrounds[code]
            case 48: // Extended background
                if i + 1 < codes.count && codes[i + 1] == 5 && i + 2 < codes.count {
                    attributes.backgroundColor = color256(codes[i + 2])
                    i += 2
                } else if i + 1 < codes.count && codes[i + 1] == 2 && i + 4 < codes.count {
                    attributes.backgroundColor = Color(
                        red: Double(codes[i + 2]) / 255.0,
                        green: Double(codes[i + 3]) / 255.0,
                        blue: Double(codes[i + 4]) / 255.0
                    )
                    i += 4
                }
            case 49: // Default background
                attributes.backgroundColor = nil
            default:
                break
            }
            
            i += 1
        }
    }
    
    private func applyAttributes(_ string: inout AttributedString, attributes: TextAttributes) {
        let range = string.startIndex..<string.endIndex
        
        if let fg = attributes.foregroundColor {
            string[range].foregroundColor = attributes.isInverse ? nil : fg
            if attributes.isInverse {
                string[range].backgroundColor = fg
            }
        }
        
        if let bg = attributes.backgroundColor {
            string[range].backgroundColor = attributes.isInverse ? nil : bg
            if attributes.isInverse {
                string[range].foregroundColor = bg
            }
        }
        
        if attributes.isBold {
            string[range].font = .system(.body, design: .monospaced).bold()
        } else if attributes.isItalic {
            string[range].font = .system(.body, design: .monospaced).italic()
        } else {
            string[range].font = .system(.body, design: .monospaced)
        }
        
        if attributes.isUnderlined {
            string[range].underlineStyle = .single
        }
        
        if attributes.isStrikethrough {
            string[range].strikethroughStyle = .single
        }
    }
    
    /// Get color from 256-color palette
    private func color256(_ code: Int) -> Color {
        if code < 16 {
            // Standard colors
            return standardColors[code < 8 ? code + 30 : code - 8 + 90] ?? .white
        } else if code < 232 {
            // 6x6x6 color cube
            let adjusted = code - 16
            let r = (adjusted / 36) * 51
            let g = ((adjusted % 36) / 6) * 51
            let b = (adjusted % 6) * 51
            return Color(red: Double(r) / 255.0, green: Double(g) / 255.0, blue: Double(b) / 255.0)
        } else {
            // Grayscale
            let gray = (code - 232) * 10 + 8
            return Color(red: Double(gray) / 255.0, green: Double(gray) / 255.0, blue: Double(gray) / 255.0)
        }
    }
}

// MARK: - Text Attributes
private struct TextAttributes {
    var foregroundColor: Color?
    var backgroundColor: Color?
    var isBold: Bool = false
    var isDim: Bool = false
    var isItalic: Bool = false
    var isUnderlined: Bool = false
    var isInverse: Bool = false
    var isStrikethrough: Bool = false
}



