import Foundation
import GRDB

/// Embeds chunks that don't have a vector yet, in small batches at utility priority.
actor EmbeddingWorker {
    static let shared = EmbeddingWorker()

    private var running = false
    private var rerun = false
    private var paused = false

    func setPaused(_ value: Bool) { paused = value }

    /// Starts (or schedules another pass of) the background embedding loop.
    func kick() {
        if running { rerun = true; return }
        running = true
        Task.detached(priority: .utility) { await self.loop() }
    }

    private func loop() async {
        guard let embedder = Embedding.shared else { running = false; return }
        resetIfModelChanged(embedder)
        repeat {
            rerun = false
            while true {
                while paused { try? await Task.sleep(nanoseconds: 500_000_000) }
                let batch = pending(limit: 32)
                if batch.isEmpty { break }
                await embed(batch, with: embedder)
                await MainActor.run { IndexStatus.shared.embeddedCount += batch.count }
                try? await Task.sleep(nanoseconds: 20_000_000) // keep CPU use gentle
            }
        } while rerun
        running = false
        await updatePendingCount()
    }

    private struct Pending { let chunkId: Int64; let itemId: Int64; let source: ItemSource; let text: String }

    private func pending(limit: Int) -> [Pending] {
        let rows = (try? AppDatabase.shared.pool.read { db in
            try Row.fetchAll(db, sql: """
                SELECT c.id, c.item_id, i.source, c.text, i.title, i.kind
                FROM chunks c JOIN items i ON i.id = c.item_id
                LEFT JOIN embeddings e ON e.chunk_id = c.id
                WHERE e.chunk_id IS NULL
                ORDER BY i.modified_at DESC LIMIT ?
                """, arguments: [limit])
        }) ?? []
        return rows.map { r in
            let text: String = r[3]
            let title: String = r[4]
            let kind: String = r[5]
            // Code and data files are keyword-only: their word soup drowns out real matches.
            // Title-only items (no text) are embedded by their name.
            let input = Self.keywordOnlyKinds.contains(kind) ? "" : (text.isEmpty ? title : text)
            return Pending(chunkId: r[0], itemId: r[1], source: ItemSource(rawValue: r[2]) ?? .file, text: input)
        }
    }

    static let keywordOnlyKinds: Set<String> = ["code", "data"]

    private func embed(_ batch: [Pending], with embedder: Embedder) async {
        let results: [(Pending, [Float]?)] = batch.map { ($0, $0.text.isEmpty ? nil : embedder.embed($0.text)) }
        Self.save(results)
        for (p, v) in results {
            if let v { VectorIndex.shared.append(chunkId: p.chunkId, itemId: p.itemId, source: p.source, vector: v) }
        }
    }

    private static func save(_ results: [(Pending, [Float]?)]) {
        try? AppDatabase.shared.pool.write { db in
            for (p, v) in results {
                // A chunk with nothing embeddable gets an empty vector so it isn't retried forever.
                let data = v.map(VectorIndex.encode) ?? Data()
                try db.execute(sql: "INSERT OR REPLACE INTO embeddings (chunk_id, vector) SELECT ?, ? WHERE EXISTS (SELECT 1 FROM chunks WHERE id = ?)",
                               arguments: [p.chunkId, data, p.chunkId])
            }
        }
    }

    private func resetIfModelChanged(_ embedder: Embedder) {
        let db = AppDatabase.shared
        let policyId = embedder.id + "|skip-code-data"
        if db.meta("embedder_id") != policyId {
            db.clearEmbeddings()
            db.setMeta("embedder_id", policyId)
            VectorIndex.shared.reload()
        }
    }

    func updatePendingCount() async {
        let total = AppDatabase.shared.embeddingCount()
        await MainActor.run { IndexStatus.shared.embeddedCount = total }
    }
}
