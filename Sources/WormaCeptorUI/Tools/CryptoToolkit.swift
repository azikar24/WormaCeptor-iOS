import CommonCrypto
import CryptoKit
import Foundation
import Security

// The crypto tool's operations, matching Android's: symmetric encrypt and decrypt with AES, DES and 3DES in its
// modes and paddings, keys and IVs as Base64, hex or UTF-8 text, ciphertext as Base64. Android runs this on
// javax.crypto, which Kotlin/Native lacks, so iOS does it here on CommonCrypto, and CryptoKit for GCM.

enum CryptoAlgorithm: String, CaseIterable, Identifiable {
    case aes128, aes256, des, tripleDes

    var id: String { rawValue }

    var title: String {
        switch self {
        case .aes128: return "AES-128"
        case .aes256: return "AES-256"
        case .des: return "DES"
        case .tripleDes: return "3DES"
        }
    }

    var keyBytes: Int {
        switch self {
        case .aes128: return kCCKeySizeAES128
        case .aes256: return kCCKeySizeAES256
        case .des: return kCCKeySizeDES
        case .tripleDes: return kCCKeySize3DES
        }
    }

    var blockBytes: Int {
        isAes ? kCCBlockSizeAES128 : kCCBlockSizeDES
    }

    var isAes: Bool { self == .aes128 || self == .aes256 }

    fileprivate var commonCrypto: CCAlgorithm {
        switch self {
        case .aes128, .aes256: return CCAlgorithm(kCCAlgorithmAES)
        case .des: return CCAlgorithm(kCCAlgorithmDES)
        case .tripleDes: return CCAlgorithm(kCCAlgorithm3DES)
        }
    }
}

enum CipherMode: String, CaseIterable, Identifiable {
    case cbc, ecb, gcm, ctr, cfb, ofb

    var id: String { rawValue }
    var title: String { rawValue.uppercased() }
    var requiresIv: Bool { self != .ecb }
    /// The stream and AEAD modes ignore the padding setting, as Android forces NoPadding for them.
    var usesPadding: Bool { self == .cbc || self == .ecb }
}

enum CryptoPadding: String, CaseIterable, Identifiable {
    case pkcs5, pkcs7, none, iso10126

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pkcs5: return "PKCS5"
        case .pkcs7: return "PKCS7"
        case .none: return "None"
        case .iso10126: return "ISO10126"
        }
    }
}

enum KeyFormat: String, CaseIterable, Identifiable {
    case base64, hex, utf8

    var id: String { rawValue }

    var title: String {
        switch self {
        case .base64: return "Base64"
        case .hex: return "Hex"
        case .utf8: return "UTF-8 Text"
        }
    }
}

struct CryptoConfig: Equatable {
    var algorithm: CryptoAlgorithm
    var mode: CipherMode
    var padding: CryptoPadding
    var key: String
    var iv: String
    var keyFormat: KeyFormat

    static let standard = CryptoConfig(
        algorithm: .aes256, mode: .cbc, padding: .pkcs5, key: "", iv: "", keyFormat: .base64
    )
}

/// Android's presets. Applying one clears the key and IV, as on Android.
enum CryptoPreset: String, CaseIterable, Identifiable {
    case aes256Gcm, aes256Cbc, aes128Cbc, tripleDesCbc

    var id: String { rawValue }

    var title: String {
        switch self {
        case .aes256Gcm: return "AES-256 GCM"
        case .aes256Cbc: return "AES-256 CBC"
        case .aes128Cbc: return "AES-128 CBC"
        case .tripleDesCbc: return "3DES CBC"
        }
    }

    var summary: String {
        switch self {
        case .aes256Gcm: return "Recommended for modern applications"
        case .aes256Cbc: return "Common for API responses"
        case .aes128Cbc: return "Legacy compatibility"
        case .tripleDesCbc: return "Legacy systems"
        }
    }

    var config: CryptoConfig {
        switch self {
        case .aes256Gcm:
            return CryptoConfig(algorithm: .aes256, mode: .gcm, padding: .none, key: "", iv: "", keyFormat: .base64)
        case .aes256Cbc: return .standard
        case .aes128Cbc:
            return CryptoConfig(algorithm: .aes128, mode: .cbc, padding: .pkcs5, key: "", iv: "", keyFormat: .base64)
        case .tripleDesCbc:
            return CryptoConfig(
                algorithm: .tripleDes, mode: .cbc, padding: .pkcs5, key: "", iv: "", keyFormat: .base64
            )
        }
    }
}

struct CryptoFailure: LocalizedError, Equatable {
    let message: String
    var errorDescription: String? { message }

    static let badPadding = CryptoFailure(message: "Decryption failed: Invalid padding (wrong key/IV or corrupted data)")
    static let badTag = CryptoFailure(message: "Decryption failed: Authentication tag mismatch (wrong key/IV)")
    static let badBlockSize = CryptoFailure(message: "Decryption failed: Invalid block size (corrupted data)")
}

enum CryptoToolkit {
    static let gcmTagBytes = 16
    static let gcmIvBytes = 12

    /// Encrypts UTF-8 `plaintext` and returns Base64, as Android's tool does.
    static func encrypt(_ plaintext: String, config: CryptoConfig) throws -> String {
        let (key, iv) = try material(config)
        return try encrypt(Data(plaintext.utf8), key: key, iv: iv, config: config).base64EncodedString()
    }

    /// Decrypts Base64 `ciphertext` and returns the plaintext as UTF-8, invalid sequences replaced.
    static func decrypt(_ ciphertext: String, config: CryptoConfig) throws -> String {
        let (key, iv) = try material(config)
        guard let data = decodeBase64(ciphertext) else {
            throw CryptoFailure(message: "Input is not valid Base64")
        }
        return String(decoding: try decrypt(data, key: key, iv: iv, config: config), as: UTF8.self)
    }

    static func encrypt(_ plaintext: Data, key: Data, iv: Data?, config: CryptoConfig) throws -> Data {
        if config.mode == .gcm { return try sealGcm(plaintext, key: key, iv: iv ?? Data(), algorithm: config.algorithm) }
        let block = config.algorithm.blockBytes
        if config.mode.usesPadding && config.padding == .iso10126 {
            return try commonCrypto(.encrypt, iso10126Pad(plaintext, block: block), key: key, iv: iv, config, pkcs7: false)
        }
        let pkcs7 = config.mode.usesPadding && config.padding != .none
        return try commonCrypto(.encrypt, plaintext, key: key, iv: iv, config, pkcs7: pkcs7)
    }

    static func decrypt(_ ciphertext: Data, key: Data, iv: Data?, config: CryptoConfig) throws -> Data {
        if config.mode == .gcm { return try openGcm(ciphertext, key: key, iv: iv ?? Data(), algorithm: config.algorithm) }
        // CommonCrypto's PKCS7 check accepts a final 0x00, so padding is checked here, as strictly as javax.crypto.
        let padded = try commonCrypto(.decrypt, ciphertext, key: key, iv: iv, config, pkcs7: false)
        guard config.mode.usesPadding else { return padded }
        switch config.padding {
        case .none: return padded
        case .iso10126: return try unpad(padded, block: config.algorithm.blockBytes, strict: false)
        case .pkcs5, .pkcs7: return try unpad(padded, block: config.algorithm.blockBytes, strict: true)
        }
    }

    /// A random key of the algorithm's length in the config's format.
    static func generateKey(_ config: CryptoConfig) -> String {
        random(count: config.algorithm.keyBytes, format: config.keyFormat)
    }

    /// A random IV: 12 bytes for GCM, else the algorithm's block size.
    static func generateIv(_ config: CryptoConfig) -> String {
        random(count: ivBytes(config), format: config.keyFormat)
    }

    static func ivBytes(_ config: CryptoConfig) -> Int {
        config.mode == .gcm ? gcmIvBytes : config.algorithm.blockBytes
    }

    /// Android's checks, with its messages, then the key and IV bytes.
    static func material(_ config: CryptoConfig) throws -> (key: Data, iv: Data?) {
        guard !config.key.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw CryptoFailure(message: "Key is required")
        }
        if config.mode.requiresIv && config.iv.trimmingCharacters(in: .whitespaces).isEmpty {
            throw CryptoFailure(message: "IV is required for \(config.mode.title) mode")
        }
        let key = try parse(config.key, config.keyFormat, what: "Key")
        guard key.count == config.algorithm.keyBytes else {
            throw CryptoFailure(
                message: "Invalid key length: expected \(config.algorithm.keyBytes) bytes "
                    + "for \(config.algorithm.title), got \(key.count) bytes"
            )
        }
        guard config.mode.requiresIv else { return (key, nil) }
        let iv = try parse(config.iv, config.keyFormat, what: "IV")
        if config.mode != .gcm && iv.count != config.algorithm.blockBytes {
            throw CryptoFailure(message: "Wrong IV length: must be \(config.algorithm.blockBytes) bytes long")
        }
        return (key, iv)
    }

    static func parse(_ value: String, _ format: KeyFormat, what: String) throws -> Data {
        switch format {
        case .utf8:
            return Data(value.utf8)
        case .base64:
            guard let data = decodeBase64(value) else { throw CryptoFailure(message: "\(what) is not valid Base64") }
            return data
        case .hex:
            guard let data = decodeHex(value) else { throw CryptoFailure(message: "\(what) is not valid hex") }
            return data
        }
    }

    static func hex(_ data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Encodings

    /// Accepts missing padding and line breaks, as Android's decoder does.
    private static func decodeBase64(_ text: String) -> Data? {
        var compact = text.filter { !$0.isWhitespace }
        let remainder = compact.count % 4
        if remainder == 1 { return nil }
        if remainder > 0 { compact += String(repeating: "=", count: 4 - remainder) }
        return Data(base64Encoded: compact)
    }

    /// Two digits per byte; an odd last digit is a byte of its own, as Android parses it.
    private static func decodeHex(_ text: String) -> Data? {
        let characters = Array(text)
        var bytes = [UInt8]()
        for start in stride(from: 0, to: characters.count, by: 2) {
            let pair = String(characters[start..<min(start + 2, characters.count)])
            guard let byte = UInt8(pair, radix: 16) else { return nil }
            bytes.append(byte)
        }
        return Data(bytes)
    }

    private static func random(count: Int, format: KeyFormat) -> String {
        var bytes = [UInt8](repeating: 0, count: count)
        guard SecRandomCopyBytes(kSecRandomDefault, count, &bytes) == errSecSuccess else {
            preconditionFailure("SecRandomCopyBytes failed")
        }
        switch format {
        case .base64: return Data(bytes).base64EncodedString()
        case .hex: return hex(Data(bytes))
        // Printable ASCII without space ("!" to "~"), one UTF-8 byte per character.
        case .utf8: return String(bytes.map { Character(UnicodeScalar(0x21 + $0 % 94)) })
        }
    }

    // MARK: - Ciphers

    private enum Direction {
        case encrypt, decrypt

        var operation: CCOperation {
            CCOperation(self == .encrypt ? kCCEncrypt : kCCDecrypt)
        }
    }

    private static func commonCrypto(
        _ direction: Direction,
        _ input: Data,
        key: Data,
        iv: Data?,
        _ config: CryptoConfig,
        pkcs7: Bool
    ) throws -> Data {
        var cryptor: CCCryptorRef?
        let status = key.withUnsafeBytes { keyBytes in
            (iv ?? Data()).withUnsafeBytes { ivBytes in
                CCCryptorCreateWithMode(
                    direction.operation, mode(config.mode), config.algorithm.commonCrypto,
                    CCPadding(pkcs7 ? ccPKCS7Padding : ccNoPadding),
                    iv == nil ? nil : ivBytes.baseAddress, keyBytes.baseAddress, key.count,
                    nil, 0, 0, 0, &cryptor
                )
            }
        }
        guard status == kCCSuccess, let cryptor else { throw failure(status, direction, config) }
        defer { CCCryptorRelease(cryptor) }

        var output = Data(count: CCCryptorGetOutputLength(cryptor, input.count, true))
        let capacity = output.count
        var written = 0
        let updateStatus = input.withUnsafeBytes { inBytes in
            output.withUnsafeMutableBytes { outBytes in
                CCCryptorUpdate(cryptor, inBytes.baseAddress, input.count, outBytes.baseAddress, capacity, &written)
            }
        }
        guard updateStatus == kCCSuccess else { throw failure(updateStatus, direction, config) }
        var finalWritten = 0
        let finalStatus = output.withUnsafeMutableBytes { outBytes in
            CCCryptorFinal(cryptor, outBytes.baseAddress.map { $0 + written }, capacity - written, &finalWritten)
        }
        guard finalStatus == kCCSuccess else { throw failure(finalStatus, direction, config) }
        return output.prefix(written + finalWritten)
    }

    private static func mode(_ mode: CipherMode) -> CCMode {
        switch mode {
        case .ecb: return CCMode(kCCModeECB)
        case .ctr: return CCMode(kCCModeCTR)
        case .cfb: return CCMode(kCCModeCFB)
        case .ofb: return CCMode(kCCModeOFB)
        default: return CCMode(kCCModeCBC)
        }
    }

    private static func failure(_ status: CCCryptorStatus, _ direction: Direction, _ config: CryptoConfig) -> CryptoFailure {
        switch (Int(status), direction) {
        case (kCCAlignmentError, .decrypt): return .badBlockSize
        case (kCCAlignmentError, .encrypt):
            return CryptoFailure(message: "Input length not multiple of \(config.algorithm.blockBytes) bytes")
        default:
            return CryptoFailure(message: "\(config.algorithm.title)/\(config.mode.title) failed (CommonCrypto \(status))")
        }
    }

    /// Ciphertext followed by the 16-byte tag, as javax.crypto writes it.
    private static func sealGcm(_ plaintext: Data, key: Data, iv: Data, algorithm: CryptoAlgorithm) throws -> Data {
        guard algorithm.isAes else { throw CryptoFailure(message: "GCM mode needs AES-128 or AES-256") }
        let box = try AES.GCM.seal(plaintext, using: SymmetricKey(data: key), nonce: try nonce(iv))
        return box.ciphertext + box.tag
    }

    private static func openGcm(_ sealed: Data, key: Data, iv: Data, algorithm: CryptoAlgorithm) throws -> Data {
        guard algorithm.isAes else { throw CryptoFailure(message: "GCM mode needs AES-128 or AES-256") }
        guard sealed.count >= gcmTagBytes else { throw CryptoFailure.badTag }
        do {
            let box = try AES.GCM.SealedBox(
                nonce: try nonce(iv),
                ciphertext: sealed.dropLast(gcmTagBytes),
                tag: sealed.suffix(gcmTagBytes)
            )
            return try AES.GCM.open(box, using: SymmetricKey(data: key))
        } catch CryptoKitError.authenticationFailure {
            throw CryptoFailure.badTag
        }
    }

    private static func nonce(_ iv: Data) throws -> AES.GCM.Nonce {
        do {
            return try AES.GCM.Nonce(data: iv)
        } catch CryptoKitError.incorrectParameterSize {
            throw CryptoFailure(message: "Wrong IV length for GCM: use \(gcmIvBytes) bytes")
        }
    }

    /// Random filler, then the pad length in the last byte; a whole block when the input is aligned.
    private static func iso10126Pad(_ data: Data, block: Int) -> Data {
        let count = block - data.count % block
        var filler = [UInt8](repeating: 0, count: count - 1)
        _ = SecRandomCopyBytes(kSecRandomDefault, filler.count, &filler)
        return data + filler + [UInt8(count)]
    }

    /// Drops the padding the last byte counts. `strict` (PKCS7) also requires every padding byte to repeat it.
    private static func unpad(_ data: Data, block: Int, strict: Bool) throws -> Data {
        guard let last = data.last, (1...block).contains(Int(last)), Int(last) <= data.count else {
            throw CryptoFailure.badPadding
        }
        let count = Int(last)
        if strict && data.suffix(count).contains(where: { $0 != last }) { throw CryptoFailure.badPadding }
        return data.dropLast(count)
    }
}
