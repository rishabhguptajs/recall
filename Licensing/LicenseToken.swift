import CryptoKit
import Foundation
import IOKit

/// A Pro token issued by the license server: "<base64url(JSON)>.<base64url(Ed25519 signature)>".
/// The signature is checked with the public key below, so a token can't be forged or edited,
/// and it's tied to one Mac's device ID, so copying it to another Mac doesn't work.
struct LicenseToken: Equatable {
    let raw: String
    let licenseId: String
    let device: String
    let plan: String
    let issuedAt: Date
    /// After this date the app quietly re-checks with the server (never blocking, offline is fine).
    let recheckAfter: Date

    /// Raw Ed25519 public key matching the server's SIGNING_KEY (keys/license-signing.pem).
    static let publicKey = "7piriGej6+COQcE+/SSzuSp1nfx2Z80vOFmVg1JFrs0="

    /// Returns nil unless the signature is valid and the token is a Pro token for this Mac.
    init?(_ raw: String, device expectedDevice: String = DeviceID.current) {
        let parts = raw.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 2,
              let keyData = Data(base64Encoded: Self.publicKey),
              let key = try? Curve25519.Signing.PublicKey(rawRepresentation: keyData),
              let signature = Self.base64URLDecode(parts[1]),
              key.isValidSignature(signature, for: Data(parts[0].utf8)),
              let payload = Self.base64URLDecode(parts[0]),
              let json = try? JSONSerialization.jsonObject(with: payload) as? [String: Any],
              json["v"] as? Int == 1,
              let lid = json["lid"] as? String,
              let dev = json["dev"] as? String,
              let plan = json["plan"] as? String,
              let iat = json["iat"] as? Double,
              let chk = json["chk"] as? Double,
              dev == expectedDevice, plan == "pro"
        else { return nil }
        self.raw = raw
        licenseId = lid
        device = dev
        self.plan = plan
        issuedAt = Date(timeIntervalSince1970: iat)
        recheckAfter = Date(timeIntervalSince1970: chk)
    }

    static func base64URLDecode(_ s: Substring) -> Data? {
        var t = s.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while t.count % 4 != 0 { t += "=" }
        return Data(base64Encoded: t)
    }
}

/// An anonymous, stable ID for this Mac: a salted SHA-256 of the hardware UUID.
/// The server only ever sees this hash, never the UUID, serial number or Mac name.
enum DeviceID {
    static let current: String = {
        let uuid = hardwareUUID() ?? fallbackID()
        let digest = SHA256.hash(data: Data("recall-device-v1|\(uuid)".utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }()

    private static func hardwareUUID() -> String? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        let value = IORegistryEntryCreateCFProperty(service, "IOPlatformUUID" as CFString, kCFAllocatorDefault, 0)
        return value?.takeRetainedValue() as? String
    }

    /// Used only if the hardware UUID can't be read: a random ID kept in preferences.
    private static func fallbackID() -> String {
        let key = "fallbackDeviceID"
        if let id = UserDefaults.standard.string(forKey: key) { return id }
        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: key)
        return id
    }
}
