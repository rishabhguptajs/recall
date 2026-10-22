import Foundation
import GRDB

struct SearchResult: Identifiable, Equatable {
    let id: Int64            // item id
    let source: ItemSource
    let path: String?
    let title: String
    let kind: String
    /// Snippet with matched terms wrapped in \u{2} … \u{3}.
    let snippet: String
    let date: Date
    let thumbnailPath: String?
    var score: Double
}

/// A query with filter tokens (`/s`, `/c`, `/f`) pulled out.
struct ParsedQuery {
    var text: String
    var source: ItemSource?

    init(_ raw: String) {
        var words: [Substring] = []
        source = nil
        for word in raw.split(separator: " ") {
            switch word.lowercased() {
            case "/s": source = .screenshot
            case "/c": source = .clipboard
            case "/f": source = .file
            default: words.append(word)
            }
        }
        text = words.joined(separator: " ")
    }

    /// Lowercased word tokens, punctuation removed.
    var terms: [String] {
        text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }
}

final class SearchEngine {
    static let shared = SearchEngine()
    private let db = AppDatabase.shared

    static let stopwords: Set<String> = [
        "a", "an", "the", "and", "or", "of", "to", "in", "on", "for", "with", "about", "that", "this",
        "is", "it", "my", "i", "me", "from", "at", "by", "as", "was", "be", "some", "thing", "one",
    ]

    func search(_ raw: String, limit: Int = 40) -> [SearchResult] {
        let q = ParsedQuery(raw)
        let terms = q.terms
        guard !terms.isEmpty else { return [] }
        let hits = keywordSearch(terms: terms, source: q.source, limit: limit)
        return load(hits, limit: limit)
    }

    // MARK: - Keyword (FTS5)

    struct Hit { let itemId: Int64; let chunkId: Int64; let snippet: String }

    /// All-terms match first, then any-term match (minus stopwords) to fill up the list.
    func keywordSearch(terms: [String], source: ItemSource?, limit: Int) -> [Hit] {
        let quoted = terms.map { "\"\($0)\"" + ($0.count >= 2 ? "*" : "") }
        var hits = runFTS(quoted.joined(separator: " "), source: source, limit: limit)
        if hits.count < limit {
            let loose = terms.filter { !Self.stopwords.contains($0) }
            if loose.count > 1 || (loose.count == 1 && loose.count < terms.count) {
                let orQuery = loose.map { "\"\($0)\"" + ($0.count >= 2 ? "*" : "") }.joined(separator: " OR ")
                let seen = Set(hits.map(\.itemId))
                hits += runFTS(orQuery, source: source, limit: limit).filter { !seen.contains($0.itemId) }
            }
        }
        return hits
    }

    private func runFTS(_ match: String, source: ItemSource?, limit: Int) -> [Hit] {
        var sql = """
            SELECT c.item_id, chunks_fts.rowid,
                   snippet(chunks_fts, 1, char(2), char(3), '…', 14),
                   bm25(chunks_fts, 4.0, 1.0) AS rank
            FROM chunks_fts
            JOIN chunks c ON c.id = chunks_fts.rowid
            JOIN items i ON i.id = c.item_id
            WHERE chunks_fts MATCH ?
            """
        var args: [DatabaseValueConvertible] = [match]
        if let source {
            sql += " AND i.source = ?"
            args.append(source.rawValue)
        }
        sql += " ORDER BY rank LIMIT \(limit * 8)"
        let rows = (try? db.pool.read { try Row.fetchAll($0, sql: sql, arguments: StatementArguments(args)) }) ?? []
        var seen = Set<Int64>()
        var hits: [Hit] = []
        for r in rows {
            let itemId: Int64 = r[0]
            guard seen.insert(itemId).inserted else { continue } // best chunk per item
            hits.append(Hit(itemId: itemId, chunkId: r[1], snippet: r[2] ?? ""))
            if hits.count >= limit { break }
        }
        return hits
    }

    // MARK: - Load item metadata

    private func load(_ hits: [Hit], limit: Int) -> [SearchResult] {
        guard !hits.isEmpty else { return [] }
        let ids = hits.prefix(limit).map(\.itemId)
        let placeholders = ids.map { _ in "?" }.joined(separator: ",")
        let rows = (try? db.pool.read {
            try Row.fetchAll($0, sql: """
                SELECT id, source, path, title, kind, modified_at, thumbnail_path
                FROM items WHERE id IN (\(placeholders))
                """, arguments: StatementArguments(ids))
        }) ?? []
        var byId: [Int64: Row] = [:]
        for r in rows { byId[r[0]] = r }
        return hits.prefix(limit).enumerated().compactMap { rank, hit in
            guard let r = byId[hit.itemId] else { return nil }
            let path: String? = r[2]
            let snippet = hit.snippet.isEmpty ? (path ?? "") : hit.snippet
            return SearchResult(
                id: hit.itemId, source: ItemSource(rawValue: r[1]) ?? .file, path: path, title: r[3],
                kind: r[4], snippet: snippet, date: Date(timeIntervalSince1970: r[5]),
                thumbnailPath: r[6], score: Double(limit - rank))
        }
    }
}
