import Foundation

/// Splits text into ~800-character chunks with ~100 characters of overlap, breaking on whitespace.
enum Chunker {
    static func chunks(_ raw: String, size: Int = 800, overlap: Int = 100) -> [String] {
        let text = normalize(raw)
        guard !text.isEmpty else { return [] }
        let chars = Array(text)
        if chars.count <= size { return [text] }

        var result: [String] = []
        var start = 0
        while start < chars.count {
            var end = min(start + size, chars.count)
            if end < chars.count {
                // Back up to the last whitespace in the final 20% of the window.
                var cut = end
                while cut > start + size * 4 / 5, !chars[cut - 1].isWhitespace { cut -= 1 }
                if cut > start + size * 4 / 5 { end = cut }
            }
            result.append(String(chars[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines))
            if end >= chars.count { break }
            start = max(end - overlap, start + 1)
        }
        return result.filter { !$0.isEmpty }
    }

    /// Collapses runs of spaces and blank lines so chunks hold more content.
    static func normalize(_ s: String) -> String {
        var out = ""
        out.reserveCapacity(s.count)
        var lastWasSpace = false
        var newlines = 0
        for ch in s {
            if ch.isNewline {
                newlines += 1
                if newlines <= 2 { out.append("\n") }
                lastWasSpace = true
            } else if ch.isWhitespace {
                if !lastWasSpace { out.append(" ") }
                lastWasSpace = true
            } else {
                out.append(ch)
                lastWasSpace = false
                newlines = 0
            }
        }
        return out.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
