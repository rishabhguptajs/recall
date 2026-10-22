import Accelerate
import Foundation
import GRDB

/// All chunk vectors in one contiguous Float32 matrix; brute-force cosine search with vDSP.
/// Vectors are stored unit-length, so cosine similarity is a plain dot product.
final class VectorIndex {
    static let shared = VectorIndex()

    private let lock = NSLock()
    private var matrix: [Float] = []
    private var chunkIds: [Int64] = []
    private var itemIds: [Int64] = []
    private var sources: [UInt8] = []
    private var dimension = 0
    private var loaded = false

    struct Hit { let itemId: Int64; let chunkId: Int64; let score: Float }

    var count: Int { lock.withLock { chunkIds.count } }

    /// (Re)loads every stored vector from the database.
    func reload() {
        let rows = (try? AppDatabase.shared.pool.read { db in
            try Row.fetchAll(db, sql: """
                SELECT e.chunk_id, c.item_id, i.source, e.vector
                FROM embeddings e JOIN chunks c ON c.id = e.chunk_id JOIN items i ON i.id = c.item_id
                """)
        }) ?? []
        var m: [Float] = []
        var cids: [Int64] = [], iids: [Int64] = [], srcs: [UInt8] = []
        var dim = 0
        for r in rows {
            let data: Data = r[3]
            let v = Self.decode(data)
            if v.isEmpty { continue } // chunk had nothing embeddable
            if dim == 0 { dim = v.count; m.reserveCapacity(rows.count * dim) }
            guard v.count == dim else { continue }
            m.append(contentsOf: v)
            cids.append(r[0]); iids.append(r[1]); srcs.append(Self.code(r[2]))
        }
        lock.withLock {
            matrix = m; chunkIds = cids; itemIds = iids; sources = srcs; dimension = dim; loaded = true
        }
    }

    func append(chunkId: Int64, itemId: Int64, source: ItemSource, vector: [Float]) {
        lock.withLock {
            guard loaded else { return } // picked up by the first reload
            if dimension == 0 { dimension = vector.count }
            guard vector.count == dimension else { return }
            matrix.append(contentsOf: vector)
            chunkIds.append(chunkId); itemIds.append(itemId); sources.append(Self.code(source.rawValue))
        }
    }

    /// Top chunks by cosine similarity, best chunk per item, optionally limited to one source.
    func search(_ query: [Float], source: ItemSource?, limit: Int, minScore: Float) -> [Hit] {
        if !lock.withLock({ loaded }) { reload() }
        return lock.withLock {
            let n = chunkIds.count
            guard n > 0, query.count == dimension else { return [] }
            var scores = [Float](repeating: 0, count: n)
            // scores = matrix (n×d) · query (d×1)
            matrix.withUnsafeBufferPointer { m in
                query.withUnsafeBufferPointer { q in
                    vDSP_mmul(m.baseAddress!, 1, q.baseAddress!, 1, &scores, 1,
                              vDSP_Length(n), 1, vDSP_Length(dimension))
                }
            }
            let wanted = source.map { Self.code($0.rawValue) }
            var order = Array(0..<n).filter { scores[$0] >= minScore && (wanted == nil || sources[$0] == wanted) }
            order.sort { scores[$0] > scores[$1] }
            var seen = Set<Int64>()
            var hits: [Hit] = []
            for i in order where seen.insert(itemIds[i]).inserted {
                hits.append(Hit(itemId: itemIds[i], chunkId: chunkIds[i], score: scores[i]))
                if hits.count >= limit { break }
            }
            return hits
        }
    }

    static func encode(_ v: [Float]) -> Data { v.withUnsafeBufferPointer { Data(buffer: $0) } }

    static func decode(_ d: Data) -> [Float] {
        d.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
    }

    private static func code(_ source: String) -> UInt8 {
        switch source { case "screenshot": 1; case "clipboard": 2; default: 0 }
    }
}
