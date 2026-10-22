import Foundation
import NaturalLanguage

/// Turns text into a unit-length vector. Swap the implementation (e.g. a Core ML MiniLM) without
/// touching indexing or search; changing `id` makes the app re-embed everything.
protocol Embedder: AnyObject {
    var id: String { get }
    var dimension: Int { get }
    /// Meaning matches below this cosine similarity are dropped (each model has its own scale).
    var minSimilarity: Float { get }
    func embed(_ text: String) -> [Float]?
}

/// Apple's built-in NLContextualEmbedding, mean-pooled over tokens into one vector per text.
///
/// Raw mean-pooled contextual vectors all point in a similar direction, which makes cosine
/// similarity weak. Two fixes make it usable: text is reduced to words (digits/punctuation removed),
/// and a fixed "average text" vector is subtracted before normalising.
final class ContextualEmbedder: Embedder {
    let id: String
    let dimension: Int
    let minSimilarity: Float = 0.12
    private let model: NLContextualEmbedding
    private let lock = NSLock()
    private var mean: [Double] = []

    /// Returns nil when the model is missing. Never triggers a download (no network calls).
    init?() {
        guard let m = NLContextualEmbedding(language: .english), m.hasAvailableAssets else { return nil }
        do { try m.load() } catch { return nil }
        model = m
        dimension = m.dimension
        id = "nlcontextual-\(m.modelIdentifier)-r\(m.revision)-centered-v1"
        mean = computeMean()
    }

    func embed(_ text: String) -> [Float]? {
        lock.lock()
        defer { lock.unlock() }
        guard let raw = meanPooled(Self.clean(text)) else { return nil }
        var v = zip(raw, mean).map { Float($0 - $1) }
        let norm = sqrt(v.reduce(0) { $0 + $1 * $1 })
        guard norm > 0 else { return nil }
        for i in v.indices { v[i] /= norm }
        return v
    }

    /// Words only, collapsed whitespace, capped length (the model reads ~256 tokens).
    static func clean(_ text: String) -> String {
        let words = text.replacingOccurrences(of: "[^\\p{L}]+", with: " ", options: .regularExpression)
            .split(separator: " ")
        return words.prefix(160).joined(separator: " ")
    }

    private func meanPooled(_ text: String) -> [Double]? {
        guard !text.isEmpty, let result = try? model.embeddingResult(for: text, language: .english) else { return nil }
        var sum = [Double](repeating: 0, count: dimension)
        var count = 0.0
        result.enumerateTokenVectors(in: text.startIndex..<text.endIndex) { vector, _ in
            for i in 0..<min(vector.count, sum.count) { sum[i] += vector[i] }
            count += 1
            return true
        }
        guard count > 0 else { return nil }
        return sum.map { $0 / count }
    }

    /// Average vector over a fixed, varied set of everyday texts. Fixed so stored vectors stay comparable.
    private func computeMean() -> [Double] {
        var acc = [Double](repeating: 0, count: dimension)
        var n = 0.0
        for s in Self.backgroundTexts {
            guard let v = meanPooled(Self.clean(s)) else { continue }
            for i in acc.indices { acc[i] += v[i] }
            n += 1
        }
        return n > 0 ? acc.map { $0 / n } : acc
    }

    static let backgroundTexts = [
        "Invoice due on March total amount owed", "git commit fix login redirect bug",
        "Dear team please find attached the quarterly report", "Flight London Heathrow to New York boarding gate",
        "import numpy as np read the csv file into a dataframe", "Terms of service by using this website you agree",
        "Happy birthday hope you have a wonderful day", "Error connection refused database server not responding",
        "Apartment lease agreement monthly rent and deposit", "Lecture notes gradient descent and backpropagation",
        "Shopping list milk eggs bread tomatoes", "The quick brown fox jumps over the lazy dog",
        "Kubernetes deployment replicas container image", "Doctor appointment Tuesday afternoon dental cleaning",
        "Password reset link expires in hours", "Chapter one it was a bright cold day in April",
        "Sales dashboard revenue up month over month", "Install the package with the command line tool",
        "Wedding invitation please reply by June", "Tax return form deductions and credits",
        "Screenshot of a chat conversation about the outage", "Hotel booking confirmation two nights breakfast included",
        "Bank statement account balance and transactions", "Resume software engineer years of experience",
        "Weather forecast rain tomorrow and cold wind", "Meeting notes roadmap review with the design team",
        "Recipe banana bread flour sugar bake in the oven", "Football match final score and highlights",
        "Rental car pickup at the airport counter", "Product launch press release new features",
        "Insurance policy coverage and claim process", "University application deadline and requirements",
        "Settings privacy notifications and account", "Error message stack trace null pointer exception",
        "Grocery delivery order confirmation", "Podcast episode about history and politics",
        "Annual performance review goals and feedback", "Home workout plan push ups and squats",
        "Movie tickets for Saturday evening show", "Electricity bill for the month of October",
    ]
}

/// Apple's built-in English word vectors (NLEmbedding.wordEmbedding), averaged over the
/// meaningful words of a text, minus a fixed "average text" vector, unit-normalised.
///
/// This is the default: on a 12-query test set it ranked the right document first 11/12 times,
/// vs 7/12 for mean-pooled NLContextualEmbedding, and it is faster and smaller (300 dims).
final class WordVectorEmbedder: Embedder {
    let id: String
    let dimension: Int
    let minSimilarity: Float = 0.12
    private let model: NLEmbedding
    private let lock = NSLock()
    private var mean: [Double] = []

    init?() {
        guard let m = NLEmbedding.wordEmbedding(for: .english) else { return nil }
        model = m
        dimension = m.dimension
        id = "nlword-en-r\(m.revision)-centered-v1"
        mean = [Double](repeating: 0, count: dimension)
        var acc = [Double](repeating: 0, count: dimension)
        var n = 0.0
        for s in ContextualEmbedder.backgroundTexts {
            guard let v = average(Self.words(s)) else { continue }
            for i in acc.indices { acc[i] += v[i] }
            n += 1
        }
        if n > 0 { mean = acc.map { $0 / n } }
    }

    func embed(_ text: String) -> [Float]? {
        lock.lock()
        defer { lock.unlock() }
        // Long chunks: the first ~400 words are plenty for the topic.
        guard let avg = average(Array(Self.words(text).prefix(400))) else { return nil }
        var v = zip(avg, mean).map { Float($0 - $1) }
        let norm = sqrt(v.reduce(0) { $0 + $1 * $1 })
        guard norm > 0 else { return nil }
        for i in v.indices { v[i] /= norm }
        return v
    }

    /// nil when none of the words are known (other languages, IDs, URLs).
    private func average(_ words: [String]) -> [Double]? {
        var acc = [Double](repeating: 0, count: dimension)
        var n = 0.0
        for w in words {
            guard let v = model.vector(for: w) else { continue }
            for i in acc.indices { acc[i] += v[i] }
            n += 1
        }
        return n > 0 ? acc.map { $0 / n } : nil
    }

    static func words(_ text: String) -> [String] {
        text.lowercased()
            .replacingOccurrences(of: "[^\\p{L}]+", with: " ", options: .regularExpression)
            .split(separator: " ")
            .map(String.init)
            .filter { $0.count > 1 && !stopwords.contains($0) }
    }

    static let stopwords: Set<String> = [
        "a", "an", "the", "and", "or", "but", "of", "to", "in", "on", "for", "with", "about", "that", "this",
        "these", "those", "is", "it", "its", "my", "me", "we", "our", "you", "your", "he", "she", "they",
        "them", "their", "from", "at", "by", "as", "was", "were", "be", "been", "are", "am", "will", "would",
        "can", "could", "should", "must", "do", "does", "did", "have", "has", "had", "not", "no", "so",
        "if", "then", "than", "there", "here", "what", "which", "who", "when", "where", "how", "all", "any",
        "some", "into", "out", "up", "down", "over", "also", "just", "only", "very", "more", "most",
    ]
}

/// The shared embedder, or nil if no on-device model is available.
enum Embedding {
    static let shared: Embedder? = MiniLMEmbedder() ?? WordVectorEmbedder() ?? ContextualEmbedder()
}
