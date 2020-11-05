//
//  Crypto.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import Foundation
import Sodium
import CommonCrypto
import CryptoKit

enum CryptoError: Error {
    case randomGeneration
    case base64Decoding
    case base64Encoding
    case keyGeneration
    case keyDerivation
    case encryption
    case decryption
    case convertToHex
    case convertFromHex
    case hashing
    case signing
    case indexOutOfRange
    case contextOverflow
}

class Crypto {

    private let seedSize = 16
    private let keySize = 32
    private let contextSize = 8
    private let paddingBlockSize = 200
    static let shared = Crypto()

    private let sodium = Sodium()

    private init() {}

    // MARK: - Key generation functions

    func generateSeed(length: Int? = nil) throws -> Data {
        guard let seed = sodium.randomBytes.buf(length: length ?? seedSize) else {
            throw CryptoError.randomGeneration
        }

        return seed.data
    }

    func generateRandomId() throws -> String {
        guard let seed = sodium.randomBytes.buf(length: keySize), let id = sodium.utils.bin2hex(seed) else {
            throw CryptoError.randomGeneration
        }
        return id
    }

    func deriveKeyFromSeed(seed: Data, keyType: KeyType, context: String) throws -> Data {

        guard context.count == 8 else {
            throw CryptoError.contextOverflow
        }

        // This expands the 128-bit seed to 256 bits by hashing. Necessary for key derivation.
        guard let seedHash = sodium.genericHash.hash(message: seed.bytes) else {
            throw CryptoError.hashing
        }

        // This derives a subkey from the seed for a given index and context.
        guard let key = sodium.keyDerivation.derive(secretKey: seedHash, index: keyType.rawValue, length: keySize, context: context) else {
            throw CryptoError.keyDerivation
        }

        return key.data
    }

    func createSessionKeyPair() throws -> KeyPair {
        guard let keyPair = sodium.box.keyPair() else {
            throw CryptoError.keyGeneration
        }

        return KeyPair(pubKey: keyPair.publicKey.data, privKey: keyPair.secretKey.data)
    }

    func generateSharedKey(pubKey: Data, privKey: Data) throws -> Data {
        guard let sharedKey = sodium.box.beforenm(recipientPublicKey: pubKey.bytes, senderSecretKey: privKey.bytes) else {
            throw CryptoError.keyDerivation
        }

        return sharedKey.data
    }

    func createSigningKeyPair(seed: Data?) throws -> KeyPair {
        guard let keyPair = (seed != nil) ? sodium.sign.keyPair(seed: seed!.bytes) : sodium.sign.keyPair() else {
            throw CryptoError.keyGeneration
        }
        return KeyPair(pubKey: keyPair.publicKey.data, privKey: keyPair.secretKey.data)
    }

    func deterministicRandomBytes(seed: Data, length: Int) throws -> Data {
        guard let keyData = sodium.randomBytes.deterministic(length: length, seed: seed.bytes) else {
            throw CryptoError.keyDerivation
        }

        return keyData.data
    }

    func deriveKey(keyData: Data, context: String, index: UInt64 = 0) throws ->  Data {
        guard context.count <= 8 else {
            throw CryptoError.contextOverflow
        }
        guard let key = sodium.keyDerivation.derive(secretKey: keyData.bytes, index: index, length: keySize, context: context) else {
            throw CryptoError.keyDerivation
        }

        return key.data
    }

    // MARK: - Conversion functions

    func convertFromBase64(from base64String: String) throws -> Data {
        guard let bytes = sodium.utils.base642bin(base64String, variant: .URLSAFE_NO_PADDING, ignore: nil) else {
            throw CryptoError.base64Decoding
        }

        return bytes.data
    }

    func convertToBase64(from data: Data) throws -> String {
        guard let b64String = sodium.utils.bin2base64(data.bytes, variant: .URLSAFE_NO_PADDING) else {
            throw CryptoError.base64Encoding
        }
        return b64String
    }

    func fromHex(_ message: String) throws -> Data {
        guard let data = sodium.utils.hex2bin(message)?.data else {
            throw CryptoError.convertFromHex
        }
        return data
    }

    // MARK: - Signing functions

    func sign(message: Data, privKey: Data) throws -> Data {
        guard let signedMessage = sodium.sign.sign(message: message.bytes, secretKey: privKey.bytes) else {
            throw CryptoError.signing
        }

        return signedMessage.data
    }

    func signature(message: Data, privKey: Data) throws -> Data {
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

    func encrypt(_ plaintext: Data, pubKey: Data) throws -> Data {
        guard let ciphertext: Bytes = sodium.box.seal(message: plaintext.bytes, recipientPublicKey: pubKey.bytes) else {
            throw CryptoError.encryption
        }

        return ciphertext.data
    }

    func encrypt(_ plaintext: Data, key: Data) throws -> Data {
        var data = plaintext.bytes
        sodium.utils.pad(bytes: &data, blockSize: paddingBlockSize)
        guard let ciphertext: Bytes = sodium.box.seal(message: data, beforenm: key.bytes) else {
            throw CryptoError.encryption
        }

        return ciphertext.data
    }

    func decrypt(_ ciphertext: Data, key: Data, version: Int) throws -> (Data, Data) {
        guard ciphertext.count > sodium.box.NonceBytes else {
            throw CryptoError.decryption
        }
        let nonce = ciphertext[..<Data.Index(sodium.box.NonceBytes)]
        guard var plaintext: Bytes = sodium.box.open(nonceAndAuthenticatedCipherText: ciphertext.bytes, beforenm: key.bytes) else {
            throw CryptoError.decryption
        }
        if version > 0 {
            sodium.utils.unpad(bytes: &plaintext, blockSize: paddingBlockSize)
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
        let hashData = try hash(message.data)

        guard let hash = sodium.utils.bin2hex(hashData.bytes) else {
            throw CryptoError.convertToHex
        }

        return hash
    }

    func sha1(from string: String) -> String {
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        _ = digest.withUnsafeMutableBytes { digestBytes in
            string.data.withUnsafeBytes { CC_SHA1($0.baseAddress, CC_LONG(string.data.count), digestBytes.bindMemory(to: UInt8.self).baseAddress) }
        }

        let hexBytes = digest.map { String(format: "%02hhx", $0) }
        return hexBytes.joined()
    }

    func sha256(from string: String) -> String {
        let digest = sha256(from: string.data(using: String.Encoding.utf8)!)
        let hexBytes = digest.map { String(format: "%02hhx", $0) }
        return hexBytes.joined()
    }

    func sha256(from data: Data) -> Data {
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        _ = digest.withUnsafeMutableBytes { digestBytes in
            data.withUnsafeBytes { CC_SHA256($0.baseAddress, CC_LONG(data.count), digestBytes.bindMemory(to: UInt8.self).baseAddress) }
        }
        return digest.data
    }

    func equals(first: Data, second: Data) -> Bool {
        return sodium.utils.equals(first.bytes, second.bytes)
    }
}

@available(iOS 13.0, *)
extension Crypto {

    func createECDSASigningKeyPair(seed: Data?) throws -> KeyPair {
        var privKey: P256.Signing.PrivateKey
        if let seed = seed {
            privKey = try P256.Signing.PrivateKey(rawRepresentation: seed)
        } else {
            privKey = P256.Signing.PrivateKey()
        }
        return KeyPair(pubKey: privKey.publicKey.rawRepresentation, privKey: privKey.rawRepresentation)
    }

}
