import Foundation

/// Converts common e-Sword RTF scripture/comment bodies into simple HTML
/// suitable for e-Sword X / mobile-style modules.
///
/// This is a pragmatic community-module converter — not a full RTF renderer.
/// Plain text and existing HTML pass through with light cleanup.
public enum RTFToHTML {
    public static func convert(_ input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "" }

        // Already looks like HTML fragment (common in newer PC modules Version=4).
        if looksLikeHTML(trimmed) {
            return sanitizeHTML(trimmed)
        }

        // Not RTF — treat as plain text.
        if !trimmed.lowercased().hasPrefix("{\\rtf") && !trimmed.contains("\\par") && !trimmed.contains("\\b") {
            return escapeHTML(trimmed)
        }

        return rtfToHTML(trimmed)
    }

    /// True if the payload still looks like RTF after conversion attempts fail soft-checks.
    public static func stillLooksLikeRTF(_ text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return t.hasPrefix("{\\rtf") || t.contains("\\pard") || t.contains("\\rtf1")
    }

    // MARK: - Internals

    private static func looksLikeHTML(_ s: String) -> Bool {
        let lower = s.lowercased()
        if lower.contains("<span") || lower.contains("<i>") || lower.contains("<b>")
            || lower.contains("<sup>") || lower.contains("<br") || lower.contains("<p")
            || lower.contains("<font") || lower.contains("</") {
            return true
        }
        return false
    }

    private static func sanitizeHTML(_ s: String) -> String {
        // Keep as-is; e-Sword HTML is intentionally simple.
        s
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }

    private static func escapeHTML(_ s: String) -> String {
        s
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private static func rtfToHTML(_ rtf: String) -> String {
        var s = rtf

        // Normalize line endings
        s = s.replacingOccurrences(of: "\r\n", with: "\n")
        s = s.replacingOccurrences(of: "\r", with: "\n")

        // Drop outer rtf wrapper when present
        if s.hasPrefix("{") && s.hasSuffix("}") {
            // leave braces; control-word parser will ignore structural ones
        }

        // Unicode escapes: \uN? (optional fallback char)
        s = decodeRTFUnicode(s)

        // Hex escaped chars \'hh
        s = decodeRTFHex(s)

        // Common formatting — order matters for simple stack-less approach.
        // Trailing space after a control word is an RTF delimiter and is consumed.
        s = replaceControl(s, #"\\b0(?:\s|$)"#, "</b>")
        s = replaceControl(s, #"\\b(?:\s|$)"#, "<b>")
        s = replaceControl(s, #"\\i0(?:\s|$)"#, "</i>")
        s = replaceControl(s, #"\\i(?:\s|$)"#, "<i>")
        s = replaceControl(s, #"\\ulnone(?:\s|$)"#, "</u>")
        s = replaceControl(s, #"\\ul0(?:\s|$)"#, "</u>")
        s = replaceControl(s, #"\\ul(?:\s|$)"#, "<u>")

        // Superscript (Strong's often use this)
        s = replaceControl(s, #"\\nosupersub(?:\s|$)"#, "</sup>")
        s = replaceControl(s, #"\\super(?:\s|$)"#, "<sup>")
        s = replaceControl(s, #"\\sub(?:\s|$)"#, "<sub>")

        // Red letter-ish color controls — map any \cfN to a span start; \cf0 ends
        // e-Sword often uses \cf2 or similar for Jesus' words.
        s = s.replacingOccurrences(
            of: #"\\cf([1-9][0-9]*)(?:\s|$)"#,
            with: #"<span style="color:#c00">"#,
            options: .regularExpression
        )
        s = replaceControl(s, #"\\cf0(?:\s|$)"#, "</span>")

        // Paragraph / line breaks
        s = replaceControl(s, #"\\par(?:\s|$)"#, "<br/>")
        s = replaceControl(s, #"\\line(?:\s|$)"#, "<br/>")
        s = replaceControl(s, #"\\tab(?:\s|$)"#, "&nbsp;&nbsp;&nbsp;&nbsp;")

        // Strip remaining control words: \word or \wordN
        s = s.replacingOccurrences(
            of: #"\\'[0-9a-fA-F]{2}"#,
            with: "",
            options: .regularExpression
        )
        s = s.replacingOccurrences(
            of: #"\\[a-zA-Z]+-?\d* ?"#,
            with: "",
            options: .regularExpression
        )

        // Remove leftover group braces
        s = s.replacingOccurrences(of: "{", with: "")
        s = s.replacingOccurrences(of: "}", with: "")

        // Unescape RTF specials
        s = s.replacingOccurrences(of: "\\\\", with: "\\")
        s = s.replacingOccurrences(of: "\\{", with: "{")
        s = s.replacingOccurrences(of: "\\}", with: "}")

        // Collapse whitespace noise from stripped headers
        s = s.replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
        s = s.trimmingCharacters(in: .whitespacesAndNewlines)

        // Balance very common tags if the RTF stream truncated mid-style
        s = balanceTag(s, "b")
        s = balanceTag(s, "i")
        s = balanceTag(s, "u")
        s = balanceTag(s, "sup")
        s = balanceTag(s, "sub")
        // spans: only close if more opens than closes
        let openSpans = s.components(separatedBy: "<span").count - 1
        let closeSpans = s.components(separatedBy: "</span>").count - 1
        if openSpans > closeSpans {
            s += String(repeating: "</span>", count: openSpans - closeSpans)
        }

        return s
    }

    private static func replaceControl(_ s: String, _ pattern: String, _ with: String) -> String {
        s.replacingOccurrences(of: pattern, with: with, options: .regularExpression)
    }

    private static func decodeRTFUnicode(_ input: String) -> String {
        // \uN followed by optional space and a fallback character
        let pattern = #"\\u(-?\d+)\s?(.)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return input }
        let ns = input as NSString
        let matches = regex.matches(in: input, range: NSRange(location: 0, length: ns.length))
        var result = input
        for match in matches.reversed() {
            guard match.numberOfRanges >= 2,
                  let full = Range(match.range, in: result),
                  let numRange = Range(match.range(at: 1), in: result)
            else { continue }
            let numStr = String(result[numRange])
            guard var value = Int32(numStr) else { continue }
            // RTF uses signed 16-bit
            if value < 0 { value = 65536 + value }
            if let scalar = UnicodeScalar(UInt32(value)) {
                result.replaceSubrange(full, with: String(Character(scalar)))
            }
        }
        return result
    }

    private static func decodeRTFHex(_ input: String) -> String {
        let pattern = #"\\'([0-9a-fA-F]{2})"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return input }
        let ns = input as NSString
        let matches = regex.matches(in: input, range: NSRange(location: 0, length: ns.length))
        var result = input
        for match in matches.reversed() {
            guard match.numberOfRanges >= 2,
                  let full = Range(match.range, in: result),
                  let hexRange = Range(match.range(at: 1), in: result)
            else { continue }
            let hex = String(result[hexRange])
            if let byte = UInt8(hex, radix: 16) {
                // Windows modules typically use Windows-1252-ish for \'hh
                let scalar = UnicodeScalar(UInt32(byte))!
                result.replaceSubrange(full, with: String(Character(scalar)))
            }
        }
        return result
    }

    private static func balanceTag(_ html: String, _ tag: String) -> String {
        let open = html.components(separatedBy: "<\(tag)>").count - 1
            + html.components(separatedBy: "<\(tag) ").count - 1
        let close = html.components(separatedBy: "</\(tag)>").count - 1
        if open > close {
            return html + String(repeating: "</\(tag)>", count: open - close)
        }
        return html
    }
}
