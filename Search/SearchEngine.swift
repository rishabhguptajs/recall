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

    func search(_ raw: String, filter: ItemSource? = nil, limit: Int = 40) -> [SearchResult] {
        var q = ParsedQuery(raw)
        if q.source == nil { q.source = filter }
        let terms = q.terms
        guard !terms.isEmpty else { return [] }
        var vector: [VectorIndex.Hit] = []
        if let embedder = Embedding.shared, let qv = embedder.embed(q.text) {
            vector = VectorIndex.shared.search(qv, source: q.source, limit: limit, minScore: embedder.minSimilarity)
        }
        // Partial-word keyword matches only fill in when meaning search found nothing: with a real
        // sentence model they mostly add noise (e.g. every screenshot containing just "table").
        let keyword = keywordSearch(terms: terms, source: q.source, limit: limit, allowLoose: vector.isEmpty)
        return load(fuse(keyword: keyword, vector: vector), limit: limit)
    }

    /// Debug: raw keyword and meaning hits for a query.
    func explain(_ raw: String) -> [String: Any] {
        let q = ParsedQuery(raw)
        let keyword = keywordSearch(terms: q.terms, source: q.source, limit: 20)
        var vector: [VectorIndex.Hit] = []
        if let e = Embedding.shared, let qv = e.embed(q.text) {
            vector = VectorIndex.shared.search(qv, source: q.source, limit: 20, minScore: -1)
        }
        let titles = Dictionary(uniqueKeysWithValues: ((try? db.pool.read {
            try Row.fetchAll($0, sql: "SELECT id, title FROM items")
        }) ?? []).map { (($0[0] as Int64), ($0[1] as String)) })
        return [
            "keyword": keyword.map { "\($0.weight) \(titles[$0.itemId] ?? "?")" },
            "vector": vector.map { "\(String(format: "%.3f", $0.score)) \(titles[$0.itemId] ?? "?")" },
        ]
    }


    // MARK: - Keyword (FTS5)

    struct Hit {
        let itemId: Int64
        let chunkId: Int64
        let snippet: String
        /// 1 for all-terms matches, 0.5 for any-term fallback matches.
        var weight: Double = 1
    }

    /// Below this many all-terms matches, any-term matches are added (at half weight).
    static let looseFallbackThreshold = 5

    /// All-terms match first, then any-term match (minus stopwords) to fill up the list.
    func keywordSearch(terms: [String], source: ItemSource?, limit: Int, allowLoose: Bool = true) -> [Hit] {
        // Require every meaningful word; filler words ("about", "the", …) are ignored unless that's all there is.
        let meaningful = terms.filter { !Self.stopwords.contains($0) }
        let quoted = (meaningful.isEmpty ? terms : meaningful).map { "\"\($0)\"" + ($0.count >= 2 ? "*" : "") }
        var hits = runFTS(quoted.joined(separator: " "), source: source, limit: limit)
        if allowLoose && hits.count < Self.looseFallbackThreshold {
            let loose = terms.filter { !Self.stopwords.contains($0) }
            if loose.count > 1 || (loose.count == 1 && loose.count < terms.count) {
                let orQuery = loose.map { "\"\($0)\"" + ($0.count >= 2 ? "*" : "") }.joined(separator: " OR ")
                let seen = Set(hits.map(\.itemId))
                hits += runFTS(orQuery, source: source, limit: limit)
                    .filter { !seen.contains($0.itemId) }
                    .map { var h = $0; h.weight = 0.5; return h }
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


    // MARK: - Hybrid ranking

    /// Reciprocal Rank Fusion constant.
    static let rrfK = 60.0
    static let recencyBoost = 0.0005

    struct Fused { let itemId: Int64; var score: Double; var snippet: String?; var chunkId: Int64? }

    /// Merges keyword and meaning results with RRF (k = 60).
    func fuse(keyword: [Hit], vector: [VectorIndex.Hit]) -> [Fused] {
        var byItem: [Int64: Fused] = [:]
        for (rank, h) in keyword.enumerated() {
            byItem[h.itemId] = Fused(itemId: h.itemId, score: h.weight / (Self.rrfK + Double(rank + 1)),
                                     snippet: h.snippet, chunkId: h.chunkId)
        }
        for (rank, h) in vector.enumerated() {
            let s = 1 / (Self.rrfK + Double(rank + 1))
            if byItem[h.itemId] != nil {
                byItem[h.itemId]!.score += s
            } else {
                byItem[h.itemId] = Fused(itemId: h.itemId, score: s, snippet: nil, chunkId: h.chunkId)
            }
        }
        return Array(byItem.values)
    }

    // MARK: - Load item metadata

    private func load(_ fused: [Fused], limit: Int) -> [SearchResult] {
        guard !fused.isEmpty else { return [] }
        let ids = fused.map(\.itemId)
        let placeholders = ids.map { _ in "?" }.joined(separator: ",")
        let rows = (try? db.pool.read {
            try Row.fetchAll($0, sql: """
                SELECT id, source, path, title, kind, modified_at, thumbnail_path
                FROM items WHERE id IN (\(placeholders))
                """, arguments: StatementArguments(ids))
        }) ?? []
        var byId: [Int64: Row] = [:]
        for r in rows { byId[r[0]] = r }

        let now = Date().timeIntervalSince1970
        var results: [SearchResult] = fused.compactMap { f in
            guard let r = byId[f.itemId] else { return nil } // item was deleted
            let modified: Double = r[5]
            // Small recency boost (worth ~1-2 rank places at the top), fading over ~30 days.
            let ageDays = max(0, (now - modified) / 86_400)
            let score = f.score + Self.recencyBoost * exp(-ageDays / 30)
            let path: String? = r[2]
            return SearchResult(
                id: f.itemId, source: ItemSource(rawValue: r[1]) ?? .file, path: path, title: r[3],
                kind: r[4], snippet: f.snippet ?? "", date: Date(timeIntervalSince1970: modified),
                thumbnailPath: r[6], score: score)
        }
        results.sort { $0.score > $1.score }
        results = Array(results.prefix(limit))

        // Meaning-only matches have no keyword snippet: show the start of the matching chunk.
        let needText = results.filter { $0.snippet.isEmpty }.compactMap { r in fused.first { $0.itemId == r.id }?.chunkId }
        let texts = db.chunkTexts(needText)
        return results.map { r in
            guard r.snippet.isEmpty else { return r }
            let chunk = fused.first { $0.itemId == r.id }?.chunkId
            let text = chunk.flatMap { texts[$0] } ?? ""
            let snippet = text.isEmpty ? (r.path ?? "") : String(text.prefix(200))
            return SearchResult(id: r.id, source: r.source, path: r.path, title: r.title, kind: r.kind,
                                snippet: snippet, date: r.date, thumbnailPath: r.thumbnailPath, score: r.score)
        }
    }
}
