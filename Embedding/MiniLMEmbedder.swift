import CoreML
import Foundation

/// all-MiniLM-L6-v2 sentence embeddings via Core ML, bundled in the app (no download at runtime).
/// The model already applies mean pooling and L2 normalisation, so its output is a unit vector.
/// Converted with scripts/convert_minilm.py.
final class MiniLMEmbedder: Embedder {
    let id = "minilm-l6-v2-coreml-fp16-v1"
    let dimension = 384
    /// Unrelated text typically scores 0.0–0.3 with this model; real matches 0.35+.
    let minSimilarity: Float = 0.25
    static let maxTokens = 256

    private let model: MLModel
    private let tokenizer: WordPieceTokenizer
    private let lock = NSLock()

    init?(bundle: Bundle = .main) {
        guard let modelURL = bundle.url(forResource: "MiniLM", withExtension: "mlmodelc"),
              let vocabURL = bundle.url(forResource: "minilm-vocab", withExtension: "txt"),
              let tok = WordPieceTokenizer(vocabURL: vocabURL) else { return nil }
        let config = MLModelConfiguration()
        // CPU only: with variable-length input it's far faster than GPU or the Neural Engine here
        // (0.7 ms for a short query, ~4 ms for a 256-token chunk on Apple Silicon).
        config.computeUnits = .cpuOnly
        guard let m = try? MLModel(contentsOf: modelURL, configuration: config) else { return nil }
        model = m
        tokenizer = tok
    }

    func tokenIds(_ text: String) -> [Int32] { tokenizer.encode(text, maxTokens: Self.maxTokens) }

    func embed(_ text: String) -> [Float]? {
        let ids = tokenIds(text)
        guard ids.count > 2 else { return nil } // nothing but [CLS] [SEP]
        lock.lock()
        defer { lock.unlock() }
        do {
            let shape = [1, NSNumber(value: ids.count)]
            let inputIds = try MLMultiArray(shape: shape, dataType: .int32)
            let mask = try MLMultiArray(shape: shape, dataType: .int32)
            for (i, id) in ids.enumerated() {
                inputIds[i] = NSNumber(value: id)
                mask[i] = 1
            }
            let input = try MLDictionaryFeatureProvider(dictionary: [
                "input_ids": MLFeatureValue(multiArray: inputIds),
                "attention_mask": MLFeatureValue(multiArray: mask),
            ])
            let out = try model.prediction(from: input)
            guard let arr = out.featureValue(for: "embedding")?.multiArrayValue, arr.count == dimension else { return nil }
            var v = [Float](repeating: 0, count: dimension)
            for i in 0..<dimension { v[i] = arr[i].floatValue }
            return v
        } catch {
            return nil
        }
    }
}
