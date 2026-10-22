import Foundation
import GRDB

enum ItemSource: String, CaseIterable {
    case file, screenshot, clipboard

    var label: String {
        switch self {
        case .file: "File"
        case .screenshot: "Screenshot"
        case .clipboard: "Clipboard"
        }
    }
}

/// Owns the SQLite database (WAL mode, safe to read from any thread).
final class AppDatabase {
    static let shared: AppDatabase = {
        do { return try AppDatabase(url: AppDatabase.defaultURL) }
        catch { fatalError("Could not open database: \(error)") }
    }()

    static var supportDirectory: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Recall", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static var defaultURL: URL { supportDirectory.appendingPathComponent("recall.sqlite") }

    let pool: DatabasePool

    init(url: URL) throws {
        var config = Configuration()
        config.prepareDatabase { db in
            try db.execute(sql: "PRAGMA foreign_keys = ON")
        }
        pool = try DatabasePool(path: url.path, configuration: config)
        try Self.migrator.migrate(pool)
    }

    private static var migrator: DatabaseMigrator {
        var m = DatabaseMigrator()
        m.registerMigration("v1") { db in
            try db.execute(sql: """
                CREATE TABLE items (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    source TEXT NOT NULL,
                    path TEXT UNIQUE,
                    title TEXT NOT NULL,
                    kind TEXT NOT NULL,
                    created_at DOUBLE NOT NULL,
                    modified_at DOUBLE NOT NULL,
                    size INTEGER NOT NULL DEFAULT 0,
                    content_hash TEXT,
                    thumbnail_path TEXT,
                    metadata_json TEXT
                );
                CREATE INDEX items_source ON items(source);
                CREATE INDEX items_hash ON items(content_hash);

                CREATE TABLE chunks (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    item_id INTEGER NOT NULL REFERENCES items(id) ON DELETE CASCADE,
                    idx INTEGER NOT NULL,
                    text TEXT NOT NULL
                );
                CREATE INDEX chunks_item ON chunks(item_id);

                CREATE VIRTUAL TABLE chunks_fts USING fts5(title, text, tokenize = 'porter unicode61');

                CREATE TRIGGER chunks_ad AFTER DELETE ON chunks BEGIN
                    DELETE FROM chunks_fts WHERE rowid = old.id;
                END;

                CREATE TABLE embeddings (
                    chunk_id INTEGER PRIMARY KEY REFERENCES chunks(id) ON DELETE CASCADE,
                    vector BLOB NOT NULL
                );
                """)
        }
        m.registerMigration("v2-meta") { db in
            try db.execute(sql: "CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT)")
        }
        return m
    }

    func meta(_ key: String) -> String? {
        try? pool.read { try String.fetchOne($0, sql: "SELECT value FROM meta WHERE key = ?", arguments: [key]) }
    }

    func setMeta(_ key: String, _ value: String) {
        try? pool.write { try $0.execute(sql: "INSERT OR REPLACE INTO meta (key, value) VALUES (?, ?)", arguments: [key, value]) }
    }

    /// Forces items of these kinds to be re-extracted on the next scan.
    func invalidateStamps(kinds: [String]) {
        let marks = kinds.map { _ in "?" }.joined(separator: ",")
        try? pool.write { try $0.execute(sql: "UPDATE items SET size = -1 WHERE source = 'file' AND kind IN (\(marks))", arguments: StatementArguments(kinds)) }
    }

    func embeddingCount() -> Int {
        (try? pool.read { try Int.fetchOne($0, sql: "SELECT count(*) FROM embeddings WHERE length(vector) > 0") }) ?? 0
    }

    func clearEmbeddings() {
        try? pool.write { try $0.execute(sql: "DELETE FROM embeddings") }
    }

    /// Text of specific chunks (used for snippets of meaning-only matches).
    func chunkTexts(_ ids: [Int64]) -> [Int64: String] {
        guard !ids.isEmpty else { return [:] }
        let marks = ids.map { _ in "?" }.joined(separator: ",")
        let rows = (try? pool.read {
            try Row.fetchAll($0, sql: "SELECT id, text FROM chunks WHERE id IN (\(marks))", arguments: StatementArguments(ids))
        }) ?? []
        var out: [Int64: String] = [:]
        for r in rows { out[r[0]] = r[1] }
        return out
    }

    // MARK: - Writes

    struct ItemFields {
        var source: ItemSource
        var path: String?
        var title: String
        var kind: String
        var createdAt: Date
        var modifiedAt: Date
        var size: Int64
        var contentHash: String
        var thumbnailPath: String?
        var metadataJSON: String?
    }

    /// Inserts or replaces an item and all of its chunks. Returns the item id.
    @discardableResult
    func upsert(_ f: ItemFields, chunks: [String]) throws -> Int64 {
        try pool.write { db in
            if let path = f.path,
               let oldId = try Int64.fetchOne(db, sql: "SELECT id FROM items WHERE path = ?", arguments: [path]) {
                try db.execute(sql: "DELETE FROM items WHERE id = ?", arguments: [oldId])
            }
            try db.execute(sql: """
                INSERT INTO items (source, path, title, kind, created_at, modified_at, size, content_hash, thumbnail_path, metadata_json)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """, arguments: [f.source.rawValue, f.path, f.title, f.kind,
                                 f.createdAt.timeIntervalSince1970, f.modifiedAt.timeIntervalSince1970,
                                 f.size, f.contentHash, f.thumbnailPath, f.metadataJSON])
            let itemId = db.lastInsertedRowID
            // Always index at least the title so the item is findable by name.
            let pieces = chunks.isEmpty ? [""] : chunks
            for (i, text) in pieces.enumerated() {
                try db.execute(sql: "INSERT INTO chunks (item_id, idx, text) VALUES (?, ?, ?)",
                               arguments: [itemId, i, text])
                let chunkId = db.lastInsertedRowID
                try db.execute(sql: "INSERT INTO chunks_fts (rowid, title, text) VALUES (?, ?, ?)",
                               arguments: [chunkId, f.title, text])
            }
            return itemId
        }
    }

    /// Updates only the file stamp when the content hash is unchanged.
    func touch(path: String, modifiedAt: Date, size: Int64) throws {
        try pool.write { db in
            try db.execute(sql: "UPDATE items SET modified_at = ?, size = ? WHERE path = ?",
                           arguments: [modifiedAt.timeIntervalSince1970, size, path])
        }
    }

    /// Deletes a file item and its thumbnail.
    func deleteItem(path: String) throws {
        let thumb = try pool.write { db -> String? in
            let t = try String.fetchOne(db, sql: "SELECT thumbnail_path FROM items WHERE path = ?", arguments: [path])
            try db.execute(sql: "DELETE FROM items WHERE path = ?", arguments: [path])
            return t
        }
        if let thumb { try? FileManager.default.removeItem(atPath: thumb) }
    }

    /// Deletes every item, plus all thumbnails and saved clipboard images.
    func deleteAll() throws {
        try pool.write { db in
            try db.execute(sql: "DELETE FROM items")
            try db.execute(sql: "DELETE FROM chunks_fts")
        }
        for dir in ["thumbs", "clips"] {
            try? FileManager.default.removeItem(at: Self.supportDirectory.appendingPathComponent(dir))
        }
    }

    /// Removes thumbnails and clipboard images that no item references any more.
    func sweepOrphanFiles() {
        let rows = (try? pool.read { try Row.fetchAll($0, sql: "SELECT thumbnail_path, metadata_json FROM items") }) ?? []
        var referenced = Set<String>()
        for r in rows {
            if let t: String = r[0] { referenced.insert(t) }
            if let image = Self.decode(r[1])["image"] as? String { referenced.insert(image) }
        }
        let fm = FileManager.default
        for dir in ["thumbs", "clips"] {
            let url = Self.supportDirectory.appendingPathComponent(dir)
            for name in (try? fm.contentsOfDirectory(atPath: url.path)) ?? [] {
                let path = url.appendingPathComponent(name).path
                if !referenced.contains(path) { try? fm.removeItem(atPath: path) }
            }
        }
    }

    // MARK: - Reads

    struct FileStamp { var modifiedAt: Double; var size: Int64; var hash: String? }

    func stamp(path: String) throws -> FileStamp? {
        try pool.read { db in
            try Row.fetchOne(db, sql: "SELECT modified_at, size, content_hash FROM items WHERE path = ?",
                             arguments: [path]).map { FileStamp(modifiedAt: $0[0], size: $0[1], hash: $0[2]) }
        }
    }

    /// All indexed paths under a folder (used to remove items whose files are gone).
    func paths(under folder: String) throws -> [String] {
        let prefix = folder.hasSuffix("/") ? folder : folder + "/"
        return try pool.read { db in
            try String.fetchAll(db, sql: "SELECT path FROM items WHERE path >= ? AND path < ?",
                                arguments: [prefix, prefix + "\u{FFFF}"])
        }
    }

    // MARK: - Clipboard

    /// If a clipboard item with this hash exists, moves it to `date` and returns true.
    func bumpClipboardItem(hash: String, to date: Date) throws -> Bool {
        try pool.write { db in
            try db.execute(sql: "UPDATE items SET modified_at = ? WHERE source = 'clipboard' AND content_hash = ?",
                           arguments: [date.timeIntervalSince1970, hash])
            return db.changesCount > 0
        }
    }

    struct ClipboardFiles { var imagePath: String?; var thumbnailPath: String? }

    /// Deletes clipboard items last copied before `date`; returns their files so they can be removed.
    func deleteClipboardItems(before date: Date) throws -> [ClipboardFiles] {
        try pool.write { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT metadata_json, thumbnail_path FROM items WHERE source = 'clipboard' AND modified_at < ?
                """, arguments: [date.timeIntervalSince1970])
            try db.execute(sql: "DELETE FROM items WHERE source = 'clipboard' AND modified_at < ?",
                           arguments: [date.timeIntervalSince1970])
            return rows.map { row in
                let meta = Self.decode(row[0])
                return ClipboardFiles(imagePath: meta["image"] as? String, thumbnailPath: row[1])
            }
        }
    }

    func metadata(itemId: Int64) -> [String: Any]? {
        let raw = try? pool.read { try String.fetchOne($0, sql: "SELECT metadata_json FROM items WHERE id = ?", arguments: [itemId]) }
        return raw.flatMap { Self.decode($0) }
    }

    private static func decode(_ json: String?) -> [String: Any] {
        guard let data = json?.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        return obj
    }

    func itemCount() -> Int {
        (try? pool.read { try Int.fetchOne($0, sql: "SELECT count(*) FROM items") }) ?? 0
    }
}
