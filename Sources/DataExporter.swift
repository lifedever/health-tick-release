import Foundation
import CryptoKit
import CommonCrypto

enum DataExporter {
    enum ExportError: LocalizedError {
        case serializationFailed
        case keyDerivationFailed
        case decryptionFailed
        case invalidFormat

        var errorDescription: String? {
            switch self {
            case .serializationFailed: return L.exportSerializationFailed
            case .keyDerivationFailed, .decryptionFailed: return L.importWrongPassword
            case .invalidFormat: return L.importMalformed
            }
        }
    }

    private static let saltLength = 16
    private static let iterations: UInt32 = 100_000

    /// Plain JSON. Up to v1.6.31 the export was AES-GCM encrypted with a password
    /// the user chose; files written by those builds still import through
    /// `decrypt`, so nobody's old backup turns into a brick.
    static func export(data: [String: Any]) throws -> Data {
        guard JSONSerialization.isValidJSONObject(data),
              let json = try? JSONSerialization.data(withJSONObject: data, options: [.sortedKeys, .prettyPrinted]) else {
            throw ExportError.serializationFailed
        }
        return json
    }

    /// Reads a plain-JSON export. nil means the bytes aren't JSON — the caller
    /// then treats the file as one of the older encrypted ones and asks for a
    /// password.
    static func parse(fileData: Data) -> [String: Any]? {
        (try? JSONSerialization.jsonObject(with: fileData)) as? [String: Any]
    }

    /// Decrypts a pre-1.6.32 export.
    static func decrypt(fileData: Data, password: String) throws -> [String: Any] {
        let nonceLength = 12
        let tagLength = 16
        let minLength = saltLength + nonceLength + tagLength
        guard fileData.count > minLength else { throw ExportError.invalidFormat }

        let salt = fileData.prefix(saltLength)
        let nonce = fileData[saltLength..<(saltLength + nonceLength)]
        let ciphertext = fileData[(saltLength + nonceLength)..<(fileData.count - tagLength)]
        let tag = fileData.suffix(tagLength)

        let key = try deriveKey(password: password, salt: salt)

        guard let aesNonce = try? AES.GCM.Nonce(data: nonce),
              let sealedBox = try? AES.GCM.SealedBox(nonce: aesNonce, ciphertext: ciphertext, tag: tag),
              let plaintext = try? AES.GCM.open(sealedBox, using: key) else {
            throw ExportError.decryptionFailed
        }

        guard let json = try? JSONSerialization.jsonObject(with: plaintext) as? [String: Any] else {
            throw ExportError.invalidFormat
        }
        return json
    }

    // MARK: - Private

    private static func deriveKey(password: String, salt: Data) throws -> SymmetricKey {
        let passwordData = Data(password.utf8)
        var derivedKey = Data(count: 32) // 256-bit
        let status = derivedKey.withUnsafeMutableBytes { derivedKeyBytes in
            salt.withUnsafeBytes { saltBytes in
                passwordData.withUnsafeBytes { passwordBytes in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBytes.baseAddress?.assumingMemoryBound(to: Int8.self),
                        passwordData.count,
                        saltBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        iterations,
                        derivedKeyBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        32
                    )
                }
            }
        }
        guard status == kCCSuccess else { throw ExportError.keyDerivationFailed }
        return SymmetricKey(data: derivedKey)
    }
}
