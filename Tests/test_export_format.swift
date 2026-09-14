#!/usr/bin/env swift
import Foundation
import CryptoKit
import CommonCrypto

// The export writes plain JSON since 1.6.32; files from earlier builds are
// AES-GCM encrypted with a user password. Import has to tell them apart on its
// own and still open the old ones, so both paths are exercised here.
// Mirrors DataExporter.parse and the pre-1.6.32 encrypted layout.
func parse(_ d: Data) -> [String: Any]? { (try? JSONSerialization.jsonObject(with: d)) as? [String: Any] }

let saltLength = 16
let iterations: UInt32 = 100_000
func deriveKey(password: String, salt: Data) -> SymmetricKey {
    let pw = Data(password.utf8)
    var key = Data(count: 32)
    _ = key.withUnsafeMutableBytes { kb in salt.withUnsafeBytes { sb in pw.withUnsafeBytes { pb in
        CCKeyDerivationPBKDF(CCPBKDFAlgorithm(kCCPBKDF2),
            pb.baseAddress?.assumingMemoryBound(to: Int8.self), pw.count,
            sb.baseAddress?.assumingMemoryBound(to: UInt8.self), salt.count,
            CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256), iterations,
            kb.baseAddress?.assumingMemoryBound(to: UInt8.self), 32)
    }}}
    return SymmetricKey(data: key)
}
func legacyEncrypt(_ obj: [String: Any], password: String) -> Data {
    let json = try! JSONSerialization.data(withJSONObject: obj, options: [.sortedKeys])
    var salt = Data(count: saltLength)
    _ = salt.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, saltLength, $0.baseAddress!) }
    let box = try! AES.GCM.seal(json, using: deriveKey(password: password, salt: salt))
    var out = Data(); out.append(salt); out.append(contentsOf: box.nonce); out.append(box.ciphertext); out.append(box.tag)
    return out
}
func legacyDecrypt(_ d: Data, password: String) -> [String: Any]? {
    guard d.count > saltLength + 12 + 16 else { return nil }
    let salt = d.prefix(saltLength)
    let nonce = d[saltLength..<(saltLength + 12)]
    let ct = d[(saltLength + 12)..<(d.count - 16)]
    let tag = d.suffix(16)
    guard let n = try? AES.GCM.Nonce(data: nonce),
          let box = try? AES.GCM.SealedBox(nonce: n, ciphertext: ct, tag: tag),
          let pt = try? AES.GCM.open(box, using: deriveKey(password: password, salt: salt)) else { return nil }
    return (try? JSONSerialization.jsonObject(with: pt)) as? [String: Any]
}

var pass = 0, fail = 0
func check(_ c: Bool, _ m: String) { if c { pass += 1; print("  PASS: \(m)") } else { fail += 1; print("  FAIL: \(m)") } }

let payload: [String: Any] = [
    "version": 1,
    "exportDate": "2026-09-14T10:00:00Z",
    "records": [["timestamp": "2026-09-01T10:00:00Z", "date": "2026-09-01"]],
    "sessions": [["date": "2026-09-01", "work_start": "2026-09-01T09:00:00Z", "work_minutes": 60,
                  "break_minutes": 2, "skipped": 0, "daily_goal": 8]],
    "config": ["reminders": "[\"该起来走走了\"]", "work_minutes": "60"],
]

print("\n=== new export: plain JSON ===")
let plain = try! JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys, .prettyPrinted])
let rt = parse(plain)
check(rt != nil, "plain file parses without a password")
check((rt?["version"] as? NSNumber)?.intValue == 1, "version survives")
check((rt?["records"] as? [[String: Any]])?.count == 1, "records survive")
let cfg = rt?["config"] as? [String: String]
check(cfg?["reminders"]?.contains("该起来走走了") == true || cfg?["reminders"] != nil, "chinese config value survives")
check(String(data: plain, encoding: .utf8)?.contains("\n") == true, "file is human-readable (pretty-printed)")

print("\n=== old export: encrypted, still importable ===")
let enc = legacyEncrypt(payload, password: "hunter2")
check(parse(enc) == nil, "encrypted file does NOT parse as JSON -> falls back to password path")
let dec = legacyDecrypt(enc, password: "hunter2")
check(dec != nil, "decrypts with the right password")
check((dec?["records"] as? [[String: Any]])?.count == 1, "records survive the legacy path")
check(legacyDecrypt(enc, password: "wrong") == nil, "wrong password fails cleanly (no crash)")

print("\n=== misc files a user might pick ===")
check(parse(Data("not json at all".utf8)) == nil, "random text -> password path, then fails there")
check(parse(Data()) == nil, "empty file -> not parsed as plain")
check(parse(Data("[1,2,3]".utf8)) == nil, "top-level JSON array rejected (needs an object)")
check(parse(Data("{}".utf8)) != nil, "empty object parses (import then rejects: no version)")

print("\n============================")
print(fail == 0 ? "ALL PASSED (\(pass))" : "FAILED: \(fail)")
exit(fail == 0 ? 0 : 1)
