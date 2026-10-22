import AppKit
import PDFKit

/// Text pulled out of a file, ready for chunking.
struct Extracted {
    var text: String
    var kind: String
    var thumbnailPath: String? = nil
}

/// One extractor per source type.
protocol Extractor {
    var extensions: Set<String> { get }
    func extract(_ url: URL) throws -> Extracted
}

enum ExtractionError: Error { case unreadable }

enum Extractors {
    static let all: [Extractor] = [PlainTextExtractor(), PDFExtractor(), RichDocumentExtractor(), ImageExtractor()]

    static func extractor(for url: URL) -> Extractor? {
        let ext = url.pathExtension.lowercased()
        return all.first { $0.extensions.contains(ext) }
    }

    static let supportedExtensions: Set<String> = all.reduce(into: []) { $0.formUnion($1.extensions) }

    /// Max characters of text kept per item.
    static let maxTextLength = 1_000_000
}

/// txt / md / code / json / csv: read directly as UTF-8 (capped at 2 MB).
struct PlainTextExtractor: Extractor {
    let extensions: Set<String> = [
        "txt", "text", "md", "markdown", "rst", "org", "log", "csv", "tsv", "json", "yaml", "yml", "toml",
        "xml", "html", "htm", "css", "scss", "js", "mjs", "ts", "tsx", "jsx", "py", "rb", "go", "rs", "swift",
        "java", "kt", "c", "h", "cpp", "cc", "hpp", "m", "mm", "cs", "php", "sh", "zsh", "bash", "sql", "ini",
        "cfg", "conf", "tex", "lua", "r", "dart", "vue", "svelte", "env", "gradle", "ipynb",
    ]
    static let maxBytes = 2 * 1024 * 1024

    func extract(_ url: URL) throws -> Extracted {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let data = try handle.read(upToCount: Self.maxBytes) ?? Data()
        // Treat files containing NUL bytes as binary.
        if data.prefix(4096).contains(0) { throw ExtractionError.unreadable }
        let ext = url.pathExtension.lowercased()
        var text = String(decoding: data, as: UTF8.self)
        if ext == "html" || ext == "htm" { text = Self.stripHTML(text) }
        let kind = Self.kind(for: ext)
        if kind == "code" || kind == "data" { text = Self.capGenerated(text, fileName: url.lastPathComponent) }
        return Extracted(text: text, kind: kind)
    }

    /// Code and data files are keyword-only. Index the first 50 KB of them (10 KB if minified,
    /// e.g. one-line JS/CSS bundles), enough to find them by name and opening content without
    /// storing megabytes of machine-generated text.
    static let codeDataLimit = 50_000
    static let minifiedLimit = 10_000

    static func capGenerated(_ text: String, fileName: String) -> String {
        guard text.utf8.count > minifiedLimit else { return text }
        let sample = text.prefix(20_000)
        let lines = max(1, sample.reduce(0) { $1 == "\n" ? $0 + 1 : $0 })
        let minified = fileName.lowercased().contains(".min.") || sample.count / lines > 400
        let limit = minified ? minifiedLimit : codeDataLimit
        return text.count > limit ? String(text.prefix(limit)) : text
    }

    /// note = prose (meaning-searchable), web = saved page text, code/data = keyword search only.
    static func kind(for ext: String) -> String {
        switch ext {
        case "md", "markdown", "txt", "text", "rst", "org", "tex": "note"
        case "html", "htm": "web"
        case "csv", "tsv", "json", "yaml", "yml", "toml", "xml", "log", "ipynb", "ini", "cfg", "conf", "env": "data"
        default: "code"
        }
    }

    /// Readable text of an HTML page: drops scripts, styles, comments and tags.
    /// Single linear pass (no regex backtracking, no WebKit).
    static func stripHTML(_ html: String) -> String {
        let src = Array(html.utf8)
        var out = [UInt8]()
        out.reserveCapacity(src.count / 2)
        var i = 0
        let n = src.count
        let skipBlocks: [[UInt8]] = ["script", "style", "noscript", "svg"].map { Array($0.utf8) }

        func lower(_ b: UInt8) -> UInt8 { (b >= 65 && b <= 90) ? b + 32 : b }
        func matches(_ word: [UInt8], at pos: Int) -> Bool {
            guard pos + word.count <= n else { return false }
            for k in 0..<word.count where lower(src[pos + k]) != word[k] { return false }
            return true
        }
        /// Index just past the first occurrence of `needle` (case-insensitive) from `pos`, or n.
        func skipPast(_ needle: [UInt8], from pos: Int) -> Int {
            var p = pos
            while p < n {
                if lower(src[p]) == needle[0] && matches(needle, at: p) { return p + needle.count }
                p += 1
            }
            return n
        }

        while i < n {
            let b = src[i]
            if b != UInt8(ascii: "<") { out.append(b); i += 1; continue }
            if matches(Array("<!--".utf8), at: i) {
                i = skipPast(Array("-->".utf8), from: i + 4)
            } else if let block = skipBlocks.first(where: { matches($0, at: i + 1) }) {
                i = skipPast(Array("</".utf8) + block, from: i + 1)
                i = skipPast([UInt8(ascii: ">")], from: i)
            } else {
                i = skipPast([UInt8(ascii: ">")], from: i + 1)
            }
            out.append(UInt8(ascii: " "))
        }
        var s = String(decoding: out, as: UTF8.self)
        for (entity, char) in [("&nbsp;", " "), ("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"), ("&quot;", "\""), ("&#39;", "'")] {
            s = s.replacingOccurrences(of: entity, with: char)
        }
        return s
    }
}

/// PDFs via PDFKit.
struct PDFExtractor: Extractor {
    let extensions: Set<String> = ["pdf"]

    func extract(_ url: URL) throws -> Extracted {
        guard let doc = PDFDocument(url: url) else { throw ExtractionError.unreadable }
        var text = ""
        for i in 0..<doc.pageCount {
            autoreleasepool {
                if let s = doc.page(at: i)?.string { text += s + "\n" }
            }
            if text.count > Extractors.maxTextLength { break }
        }
        return Extracted(text: text, kind: "pdf")
    }
}

/// docx / rtf / doc / odt via NSAttributedString document reading. Failures are skipped.
/// The document type is always set explicitly so files never go through the HTML/WebKit importer
/// (which could load remote resources). `.pages` can't be read this way, so it is indexed by name only.
struct RichDocumentExtractor: Extractor {
    let extensions: Set<String> = ["docx", "doc", "rtf", "rtfd", "odt", "pages"]

    private static let types: [String: NSAttributedString.DocumentType] = [
        "docx": .officeOpenXML, "doc": .docFormat, "rtf": .rtf, "rtfd": .rtfd, "odt": .openDocument,
    ]

    func extract(_ url: URL) throws -> Extracted {
        guard let type = Self.types[url.pathExtension.lowercased()] else { throw ExtractionError.unreadable }
        let attr = try NSAttributedString(url: url, options: [.documentType: type], documentAttributes: nil)
        return Extracted(text: attr.string, kind: "document")
    }
}
