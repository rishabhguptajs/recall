import Foundation

/// BERT "uncased" WordPiece tokenizer, matching Hugging Face's BertTokenizer
/// (clean text → split CJK → lowercase + strip accents → split punctuation → greedy longest-match WordPiece).
final class WordPieceTokenizer {
    let clsId: Int32
    let sepId: Int32
    let unkId: Int32
    private let vocab: [String: Int32]

    init?(vocabURL: URL) {
        guard let text = try? String(contentsOf: vocabURL, encoding: .utf8) else { return nil }
        var v: [String: Int32] = [:]
        for (i, line) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() where !line.isEmpty {
            v[String(line)] = Int32(i)
        }
        guard let cls = v["[CLS]"], let sep = v["[SEP]"], let unk = v["[UNK]"] else { return nil }
        vocab = v
        clsId = cls; sepId = sep; unkId = unk
    }

    /// Token ids including [CLS] … [SEP], truncated to `maxTokens` in total.
    func encode(_ text: String, maxTokens: Int) -> [Int32] {
        var ids: [Int32] = [clsId]
        let limit = maxTokens - 1
        outer: for word in basicTokens(text) {
            for id in wordPiece(word) {
                if ids.count >= limit { break outer }
                ids.append(id)
            }
        }
        ids.append(sepId)
        return ids
    }

    // MARK: - Basic tokenization

    private func basicTokens(_ text: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        func flush() {
            if !current.isEmpty { tokens.append(current); current = "" }
        }
        // Lowercase, then NFD so accents become separate combining marks we can drop.
        for scalar in text.lowercased().decomposedStringWithCanonicalMapping.unicodeScalars {
            let v = scalar.value
            if v == 0 || v == 0xFFFD || Self.isControl(scalar) { continue }
            if scalar.properties.generalCategory == .nonspacingMark { continue } // strip accents
            if Self.isWhitespace(scalar) { flush(); continue }
            if Self.isPunctuation(scalar) || Self.isCJK(v) {
                flush()
                tokens.append(String(scalar))
                continue
            }
            current.unicodeScalars.append(scalar)
        }
        flush()
        return tokens
    }

    private func wordPiece(_ word: String) -> [Int32] {
        let chars = Array(word.unicodeScalars)
        if chars.count > 100 { return [unkId] }
        var pieces: [Int32] = []
        var start = 0
        while start < chars.count {
            var end = chars.count
            var found: Int32?
            while start < end {
                var sub = String(String.UnicodeScalarView(chars[start..<end]))
                if start > 0 { sub = "##" + sub }
                if let id = vocab[sub] { found = id; break }
                end -= 1
            }
            guard let id = found else { return [unkId] } // whole word becomes [UNK]
            pieces.append(id)
            start = end
        }
        return pieces
    }

    // MARK: - Character classes (as in BERT's reference tokenizer)

    private static func isWhitespace(_ s: Unicode.Scalar) -> Bool {
        if s == " " || s == "\t" || s == "\n" || s == "\r" { return true }
        return s.properties.generalCategory == .spaceSeparator
    }

    private static func isControl(_ s: Unicode.Scalar) -> Bool {
        if s == "\t" || s == "\n" || s == "\r" { return false }
        switch s.properties.generalCategory {
        case .control, .format, .privateUse, .surrogate, .unassigned: return true
        default: return false
        }
    }

    private static func isPunctuation(_ s: Unicode.Scalar) -> Bool {
        let v = s.value
        if (33...47).contains(v) || (58...64).contains(v) || (91...96).contains(v) || (123...126).contains(v) { return true }
        switch s.properties.generalCategory {
        case .connectorPunctuation, .dashPunctuation, .openPunctuation, .closePunctuation,
             .initialPunctuation, .finalPunctuation, .otherPunctuation: return true
        default: return false
        }
    }

    private static func isCJK(_ v: UInt32) -> Bool {
        (0x4E00...0x9FFF).contains(v) || (0x3400...0x4DBF).contains(v) || (0x20000...0x2A6DF).contains(v)
            || (0x2A700...0x2B73F).contains(v) || (0x2B740...0x2B81F).contains(v) || (0x2B820...0x2CEAF).contains(v)
            || (0xF900...0xFAFF).contains(v) || (0x2F800...0x2FA1F).contains(v)
    }
}
