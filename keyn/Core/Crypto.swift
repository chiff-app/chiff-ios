/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import Foundation
import Sodium
import CommonCrypto

enum CryptoError: KeynError {
    case randomGeneration
    case base64Decoding
    case base64Encoding
    case keyGeneration
    case keyDerivation
    case encryption
    case decryption
    case convertToHex
    case hashing
    case signing
    case indexOutOfRange
}

class Crypto {
    
    private let SEED_SIZE = 16
    private let KEY_SIZE = 32
    private let CONTEXT_SIZE = 8
    static let shared = Crypto()

    private let sodium = Sodium()
    
    private init() {}

    // MARK: - Key generation functions

    func generateSeed() throws -> Data {
        guard let seed = sodium.randomBytes.buf(length: SEED_SIZE) else {
            throw CryptoError.randomGeneration
        }

        return seed.data
    }

    func deriveKeyFromSeed(seed: Data, keyType: KeyType, context: String) throws -> Data {
        // This expands the 128-bit seed to 256 bits by hashing. Necessary for key derivation.
        guard let seedHash = sodium.genericHash.hash(message: seed.bytes) else {
            throw CryptoError.hashing
        }
        
        // This derives a subkey from the seed for a given index and context.
        guard let key = sodium.keyDerivation.derive(secretKey: seedHash, index: keyType.rawValue, length: KEY_SIZE, context: String(context.prefix(CONTEXT_SIZE))) else {
            throw CryptoError.keyDerivation
        }

        return key.data
    }

    func createSessionKeyPair() throws -> Box.KeyPair {
        guard let keyPair = sodium.box.keyPair() else {
            throw CryptoError.keyGeneration
        }

        return keyPair
    }
    
    func createSigningKeyPair(seed: Data) throws -> Sign.KeyPair {
        guard let keyPair = sodium.sign.keyPair(seed: seed.bytes) else {
            throw CryptoError.keyGeneration
        }

        return keyPair
    }

    func deterministicRandomBytes(seed: Data, length: Int) throws -> Data {
        guard let keyData = sodium.randomBytes.deterministic(length: length, seed: seed.bytes) else {
            throw CryptoError.keyDerivation
        }
        
        return keyData.data
    }

    func deriveKey(keyData: Data, context: Data, index: Int = 0) throws ->  Data {
        guard index >= 0 && index < UInt64.max else {
            throw CryptoError.indexOutOfRange
        }
        guard let contextHash = sodium.genericHash.hash(message: context.bytes, outputLength: CONTEXT_SIZE) else {
            throw CryptoError.hashing
        }
        guard let context = sodium.utils.bin2base64(contextHash, variant: .ORIGINAL_NO_PADDING) else {
            throw CryptoError.base64Encoding
        }
        guard let key = sodium.keyDerivation.derive(secretKey: keyData.bytes, index: UInt64(index), length: KEY_SIZE, context: String(context.prefix(CONTEXT_SIZE))) else {
            throw CryptoError.keyDerivation
        }

        return key.data
    }
    
    
    func deriveKey(key: String, context: String, index: Int = 0) throws ->  Data {
        guard index >= 0 && index < UInt64.max else {
            throw CryptoError.indexOutOfRange
        }
        guard let keyData = sodium.utils.base642bin(key, variant: .URLSAFE_NO_PADDING, ignore: nil) else {
            throw CryptoError.base64Decoding
        }
        guard let key = sodium.keyDerivation.derive(secretKey: keyData, index: UInt64(index), length: sodium.sign.SeedBytes, context: context) else {
            throw CryptoError.keyDerivation
        }
        
        return key.data
    }

    // MARK: - Base64 conversion functions

    func convertFromBase64(from base64String: String) throws -> Data  {
        guard let bytes = sodium.utils.base642bin(base64String, variant: .URLSAFE_NO_PADDING, ignore: nil) else {
            throw CryptoError.base64Decoding
        }

        return bytes.data
    }

    func convertToBase64(from data: Data) throws -> String  {
        guard let b64String = sodium.utils.bin2base64(data.bytes, variant: .URLSAFE_NO_PADDING) else {
            throw CryptoError.base64Encoding
        }

        return b64String
    }
    
    // MARK: - Signing functions
    
    func sign(message: Data, privKey: Data) throws -> Data {
        guard let signature = sodium.sign.signature(message: message.bytes, secretKey: privKey.bytes) else {
            throw CryptoError.signing
        }
        
        return signature.data
    }

    // MARK: - Encryption & decryption functions
    
    func encryptSymmetric(_ plaintext: Data, secretKey: Data) throws -> Data {
        guard let ciphertext: Bytes = sodium.secretBox.seal(message: plaintext.bytes, secretKey: secretKey.bytes) else {
            throw CryptoError.encryption
        }
        
        return ciphertext.data
    }
    
    func decryptSymmetric(_ ciphertext: Data, secretKey: Data) throws -> Data {
        guard let plaintext: Bytes = sodium.secretBox.open(nonceAndAuthenticatedCipherText: ciphertext.bytes, secretKey: secretKey.bytes) else {
            throw CryptoError.encryption
        }
        
        return plaintext.data
    }

    func encrypt(_ plaintext: Data, pubKey: Data, privKey: Data) throws -> Data {
        guard let ciphertext: Bytes = sodium.box.seal(message: plaintext.bytes, recipientPublicKey: pubKey.bytes, senderSecretKey: privKey.bytes) else {
            throw CryptoError.encryption
        }
    
        return ciphertext.data
    }

    func encrypt(_ plaintext: Data, pubKey: Data) throws -> Data {
        guard let ciphertext: Bytes = sodium.box.seal(message: plaintext.bytes, recipientPublicKey: pubKey.bytes) else {
            throw CryptoError.encryption
        }

        return ciphertext.data
    }

    // This function should decrypt a password request with the sessions corresponding session / private key and check signature with browser's public key
    func decrypt(_ ciphertext: Data, privKey: Data, pubKey: Data) throws -> (Data, Data) {
        let nonce = ciphertext[..<Data.Index(sodium.box.NonceBytes)]
        guard let plaintext: Bytes = sodium.box.open(nonceAndAuthenticatedCipherText: ciphertext.bytes, senderPublicKey: pubKey.bytes, recipientSecretKey: privKey.bytes) else {
            throw CryptoError.decryption
        }
        
        return (plaintext.data, nonce)
    }

    // MARK: - Hash functions

    func hash(_ data: Data) throws -> Data {
        guard let hashData = sodium.genericHash.hash(message: data.bytes) else {
            throw CryptoError.hashing
        }

        return hashData.data
    }

    func hash(_ message: String) throws -> String {
        guard let messageData = message.data(using: .utf8) else {
            throw CodingError.stringDecoding
        }

        let hashData = try hash(messageData)

        guard let hash = sodium.utils.bin2hex(hashData.bytes) else {
            throw CryptoError.convertToHex
        }

        return hash
    }
    
    func sha1(from string: String) -> String {
        let data = string.data(using: String.Encoding.utf8)!
        var digest = [UInt8](repeating: 0, count:Int(CC_SHA1_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA1($0, CC_LONG(data.count), &digest)
        }
        let hexBytes = digest.map { String(format: "%02hhx", $0) }
        return hexBytes.joined()
    }
    
    func sha256(from string: String) -> String {
        let data = string.data(using: String.Encoding.utf8)!
        var digest = [UInt8](repeating: 0, count:Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0, CC_LONG(data.count), &digest)
        }
        let hexBytes = digest.map { String(format: "%02hhx", $0) }
        return hexBytes.joined()
    }
}
