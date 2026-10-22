import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers
import Vision

/// Screenshots and images: on-device text recognition (Vision, accurate mode) plus a thumbnail.
struct ImageExtractor: Extractor {
    let extensions: Set<String> = ["png", "jpg", "jpeg", "heic", "heif", "tiff", "tif", "gif", "bmp", "webp"]

    func extract(_ url: URL) throws -> Extracted {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { throw ExtractionError.unreadable }
        let thumb = Self.writeThumbnail(src, key: url.path)
        // OCR a downscaled copy (max 3000 px) to keep memory and time bounded.
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: 3000,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) else {
            return Extracted(text: "", kind: "image", thumbnailPath: thumb)
        }
        return Extracted(text: Self.recognizeText(in: image), kind: "image", thumbnailPath: thumb)
    }

    static func recognizeText(in image: CGImage) -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do { try handler.perform([request]) } catch { return "" }
        let observations = request.results ?? []
        // Top-to-bottom, left-to-right reading order.
        let sorted = observations.sorted {
            let a = $0.boundingBox, b = $1.boundingBox
            if abs(a.midY - b.midY) > 0.01 { return a.midY > b.midY }
            return a.minX < b.minX
        }
        return sorted.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
    }

    static var thumbnailDirectory: URL {
        let dir = AppDatabase.supportDirectory.appendingPathComponent("thumbs", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Writes a 256 px JPEG thumbnail; returns its path.
    static func writeThumbnail(_ src: CGImageSource, key: String) -> String? {
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: 256,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        guard let thumb = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) else { return nil }
        return writeJPEG(thumb, key: key)
    }

    static func writeJPEG(_ image: CGImage, key: String) -> String? {
        let name = SHA256.hash(data: Data(key.utf8)).prefix(16).map { String(format: "%02x", $0) }.joined()
        let url = thumbnailDirectory.appendingPathComponent(name + ".jpg")
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, image, [kCGImageDestinationLossyCompressionQuality: 0.75] as CFDictionary)
        return CGImageDestinationFinalize(dest) ? url.path : nil
    }
}

/// Decides whether an image file is a screenshot.
enum ScreenshotDetector {
    static func isScreenshot(_ url: URL) -> Bool {
        // macOS tags screenshots with this extended attribute.
        if getxattr(url.path, "com.apple.metadata:kMDItemIsScreenCapture", nil, 0, 0, 0) > 0 { return true }
        let name = url.lastPathComponent.lowercased()
        let inShotFolder = url.deletingLastPathComponent().standardizedFileURL.path
            == Preferences.screenshotFolder.standardizedFileURL.path
        let looksLikeShot = name.hasPrefix("screenshot") || name.hasPrefix("screen shot")
            || name.hasPrefix("cleanshot") || name.hasPrefix("simulator screen shot")
        return looksLikeShot || (inShotFolder && name.hasPrefix("screen"))
    }
}
