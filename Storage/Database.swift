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
        return m
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

    func deleteItem(path: String) throws {
        try pool.write { db in
            try db.execute(sql: "DELETE FROM items WHERE path = ?", arguments: [path])
        }
    }

    func deleteItems(ids: [Int64]) throws {
        guard !ids.isEmpty else { return }
        try pool.write { db in
            for id in ids { try db.execute(sql: "DELETE FROM items WHERE id = ?", arguments: [id]) }
        }
    }

    func deleteAll() throws {
        try pool.write { db in
            try db.execute(sql: "DELETE FROM items")
            try db.execute(sql: "DELETE FROM chunks_fts")
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

    func itemCount() -> Int {
        (try? pool.read { try Int.fetchOne($0, sql: "SELECT count(*) FROM items") }) ?? 0
    }
}
