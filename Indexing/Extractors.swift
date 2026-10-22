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
        let text = String(decoding: data, as: UTF8.self)
        let kind = ["md", "markdown", "txt", "text", "rst", "org"].contains(url.pathExtension.lowercased()) ? "note" : "text"
        return Extracted(text: text, kind: kind)
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
