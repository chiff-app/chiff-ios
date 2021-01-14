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
    case wrongSigningFunction
}

/// The Crypto singleton, that handles are cryptography-related operations. Uses libosodium (swift-sodium) under the hood.
class Crypto {

    /// The `Crypto` singleton instance.
    static let shared = Crypto()

    private let seedSize = 16
    private let keySize = 32
    private let contextSize = 8
    private let paddingBlockSize = 200

    private let sodium = Sodium()

    private init() {}

    // MARK: - Key generation functions

    /// Generate random data with a certain length.
    /// - Parameter length: The number of bytes that should be generated.
    /// - Throws: `CryptoError.randomGeneration` is libsodium fails.
    /// - Returns: The random data.
    func generateSeed(length: Int? = nil) throws -> Data {
        guard let seed = sodium.randomBytes.buf(length: length ?? seedSize) else {
            throw CryptoError.randomGeneration
        }

        return seed.data
    }

    /// Generates a random ID, which is a hex-encoded string of randomly generated 32 bytes.
    /// - Throws: `CryptoError.randomGeneration` is libsodium fails.
    /// - Returns: The random id, which is a hex-encoded string of randomly generated 32 bytes.
    func generateRandomId() throws -> String {
        guard let seed = sodium.randomBytes.buf(length: keySize), let id = sodium.utils.bin2hex(seed) else {
            throw CryptoError.randomGeneration
        }
        return id
    }

    /// Derive a key from a seed. For more information about the underlying mechanisms, please see [libsodium documentation](https://libsodium.gitbook.io/doc/key_derivation).
    /// - Parameters:
    ///   - seed: The seed. Should be 128-bit.
    ///   - keyType: The KeyType, which will be used as an index for the key derivation.
    ///   - context: An additional context, which should be a string of 8 characters.
    /// - Throws:
    ///     - `CryptoError.contextOverflow` if the context is not 8 characters.
    ///     - `CryptoError.hashing` if hashing operation fails.
    ///     - `CryptoError.keyDerivation` if key derivation operation fails.
    /// - Precondition: The context must be *exactly* 8 characters.
    /// - Important: This function hashes the seed, before deriving a key from it.
    ///     This is used to expand the 128-bit seed to 256 bit. If this is not required, the `deriveKey(keyData: Data, context: String, index: UInt64 = 0)` function should be used instead.
    /// - Returns: The key (256 bits).
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

    /// Create a randomly generated session keypair, which can be used to establish a shared session key.
    /// - Throws: `CryptoError.keyGeneration` when libsodium fails to generate the keypair.
    /// - Returns: The keypair.
    func createSessionKeyPair() throws -> KeyPair {
        guard let keyPair = sodium.box.keyPair() else {
            throw CryptoError.keyGeneration
        }

        return KeyPair(pubKey: keyPair.publicKey.data, privKey: keyPair.secretKey.data)
    }

    /// Generate a shared key from (our) private key and (their) public key.
    /// - Parameters:
    ///   - pubKey: The public key.
    ///   - privKey: The private key.
    /// - Throws: `CryptoError.keyGeneration` when libsodium fails to generate the key.
    /// - Returns: The shared key.
    func generateSharedKey(pubKey: Data, privKey: Data) throws -> Data {
        guard let sharedKey = sodium.box.beforenm(recipientPublicKey: pubKey.bytes, senderSecretKey: privKey.bytes) else {
            throw CryptoError.keyGeneration
        }

        return sharedKey.data
    }

    /// Create a signing keypair, either from a seed or randomly.
    /// - Parameter seed: Optionally, a seed can be provided to use as the private key.
    /// - Throws: `CryptoError.keyGeneration` when libsodium fails to generate the keypair.
    /// - Returns: The signing keypair.
    func createSigningKeyPair(seed: Data?) throws -> KeyPair {
        guard let keyPair = (seed != nil) ? sodium.sign.keyPair(seed: seed!.bytes) : sodium.sign.keyPair() else {
            throw CryptoError.keyGeneration
        }
        return KeyPair(pubKey: keyPair.publicKey.data, privKey: keyPair.secretKey.data)
    }

    /// Generate deterministic random bytes. This is mainly used to generate data for passwords, since these can (in theory) have an arbitrary size.
    /// - Parameters:
    ///   - seed: The based on which the data should be generated.
    ///   - length: The number of bytes that should be generated.
    /// - Throws: `CryptoError.randomGeneration` when libsodium fails to generate the data.
    /// - Returns: The `length` random bytes.
    func deterministicRandomBytes(seed: Data, length: Int) throws -> Data {
        guard let keyData = sodium.randomBytes.deterministic(length: length, seed: seed.bytes) else {
            throw CryptoError.randomGeneration
        }

        return keyData.data
    }

    /// Derive a key from another key.
    /// - Parameters:
    ///   - keyData: The key to be used as the source.
    ///   - context: The context, which should be exactly 8 characters.
    ///   - index: The index, as a UInt64.
    /// - Throws:
    ///     - `CryptoError.contextOverflow` if the context is not 8 characters.
    ///     - `CryptoError.keyDerivation` if key derivation operation fails.
    /// - Precondition: The context must be *exactly* 8 characters.
    /// - Returns: The derived key (256 bit).
    func deriveKey(keyData: Data, context: String, index: Data) throws ->  Data {
        var indexData: UInt64 = 0
        _ = withUnsafeMutableBytes(of: &indexData, { index.copyBytes(to: $0, from: 0..<8) })
        guard context.count <= 8 else {
            throw CryptoError.contextOverflow
        }
        guard let key = sodium.keyDerivation.derive(secretKey: keyData.bytes, index: indexData, length: keySize, context: context) else {
            throw CryptoError.keyDerivation
        }

        return key.data
    }

    /// Derive a key from another key.
    /// - Parameters:
    ///   - keyData: The key to be used as the source.
    ///   - context: The context, which should be exactly 8 characters.
    ///   - index: The index, as Data.
    /// - Throws:
    ///     - `CryptoError.contextOverflow` if the context is not 8 characters.
    ///     - `CryptoError.keyDerivation` if key derivation operation fails.
    /// - Precondition: The context must be *exactly* 8 characters.
    /// - Returns: The derived key (256 bit).
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

    /// Convert a URL-safe base64-encoded string to `Data`.
    /// - Parameter base64String: The input string.
    /// - Throws: `CryptoError.base64Decoding` if libsodium fails to decode the string.
    /// - Returns: The data.
    func convertFromBase64(from base64String: String) throws -> Data {
        guard let bytes = sodium.utils.base642bin(base64String, variant: .URLSAFE_NO_PADDING, ignore: nil) else {
            throw CryptoError.base64Decoding
        }

        return bytes.data
    }

    /// Convert data to a URL-safe base64 encoded string.
    /// - Parameter data: The input data
    /// - Throws: `CryptoError.base64Encoding` if libsodium fails to encode the string. It is unclear when this would happen.
    /// - Returns: The base64-encoded string.
    func convertToBase64(from data: Data) throws -> String {
        guard let b64String = sodium.utils.bin2base64(data.bytes, variant: .URLSAFE_NO_PADDING) else {
            throw CryptoError.base64Encoding
        }
        return b64String
    }

    /// Convert a hex-encoded string to `Data`.
    /// - Parameter message: The hex-encoded string.
    /// - Throws: `CryptoError.convertFromHex` if libsodium fails to decode the string.
    /// - Returns: The data.
    func fromHex(_ message: String) throws -> Data {
        guard let data = sodium.utils.hex2bin(message)?.data else {
            throw CryptoError.convertFromHex
        }
        return data
    }

    // MARK: - Signing functions

    /// Sign a message with a private key. Prepends the signature to the message.
    /// - Parameters:
    ///   - message: The message to be signed.
    ///   - privKey: The private key.
    /// - Throws: `CryptoError.signing` when libsodium fails to sign the message.
    /// - Returns: The signed message.
    func sign(message: Data, privKey: Data) throws -> Data {
        guard let signedMessage = sodium.sign.sign(message: message.bytes, secretKey: privKey.bytes) else {
            throw CryptoError.signing
        }

        return signedMessage.data
    }

    /// Sign a message with a private key.
    /// - Parameters:
    ///   - message: The message to be signed.
    ///   - privKey: The private key.
    /// - Throws: `CryptoError.signing` when libsodium fails to sign the message.
    /// - Returns: The signature.
    func signature(message: Data, privKey: Data) throws -> Data {
        guard let signature = sodium.sign.signature(message: message.bytes, secretKey: privKey.bytes) else {
            throw CryptoError.signing
        }

        return signature.data
    }

    // MARK: - Encryption & decryption functions

    /// Encrypts and authenticates data.
    /// - Note: Uses [libsodium secretbox](https://libsodium.gitbook.io/doc/secret-key_cryptography/secretbox) under the hood.
    /// - Parameters:
    ///   - plaintext: The data that should be encrypted.
    ///   - secretKey: The key that should be used for encryption.
    /// - Throws: `CryptoError.encryption` when libsodium fails to encrypt.
    /// - Returns: The ciphertext with a prepended authentication tag.
    func encryptSymmetric(_ plaintext: Data, secretKey: Data) throws -> Data {
        guard let ciphertext: Bytes = sodium.secretBox.seal(message: plaintext.bytes, secretKey: secretKey.bytes) else {
            throw CryptoError.encryption
        }

        return ciphertext.data
    }

    /// Checks the authentication tag and decrypt the data (if authentication is succesful).
    /// - Note: Uses [libsodium secretbox](https://libsodium.gitbook.io/doc/secret-key_cryptography/secretbox) under the hood.
    /// - Parameters:
    ///   - ciphertext: The data that should be decrypted.
    ///   - secretKey: The key that should be used for encryption.
    /// - Throws: `CryptoError.encryption` when libsodium fails to encrypt or if authentication tag is incorrect.
    /// - Returns: The ciphertext with a prepended authentication tag.
    func decryptSymmetric(_ ciphertext: Data, secretKey: Data) throws -> Data {
        guard let plaintext: Bytes = sodium.secretBox.open(nonceAndAuthenticatedCipherText: ciphertext.bytes, secretKey: secretKey.bytes) else {
            throw CryptoError.decryption
        }
        return plaintext.data
    }

    /// Anonymously encrypts data.
    /// - Important: With this method, **no authentication tag is added**. It should only be used during key exchange.
    /// - Note: Uses [libsodium sealed box](https://libsodium.gitbook.io/doc/public-key_cryptography/sealed_boxes) under the hood.
    /// - Parameters:
    ///   - plaintext: The data that should be encrypted.
    ///   - pubKey: The public key to encrypt the data with.
    /// - Throws: `CryptoError.encryption` when libsodium fails to encrypt.
    /// - Returns: The ciphertext **without** a prepended authentication tag.
    func encrypt(_ plaintext: Data, pubKey: Data) throws -> Data {
        guard let ciphertext: Bytes = sodium.box.seal(message: plaintext.bytes, recipientPublicKey: pubKey.bytes) else {
            throw CryptoError.encryption
        }

        return ciphertext.data
    }

    /// Encrypt data with a shared key that is obtained with `generateSharedKey(pubKey: Data, privKey: Data)`. This is the main method that should be used for encrypting messages with clients.
    /// - Note: Uses [libsodium](https://libsodium.gitbook.io/doc/public-key_cryptography/authenticated_encryption) under the hood.
    /// - Parameters:
    ///   - plaintext: The data that should be encrypted.
    ///   - key: The shared key, as obtained with `generateSharedKey(pubKey: Data, privKey: Data)`.
    /// - Throws: `CryptoError.encryption` when libsodium fails to encrypt.
    /// - Returns: The ciphertext with a prepended authentication tag.
    func encrypt(_ plaintext: Data, key: Data) throws -> Data {
        var data = plaintext.bytes
        sodium.utils.pad(bytes: &data, blockSize: paddingBlockSize)
        guard let ciphertext: Bytes = sodium.box.seal(message: data, beforenm: key.bytes) else {
            throw CryptoError.encryption
        }

        return ciphertext.data
    }

    /// Decrypt authenticated messages that are encrypted with `encrypt(_ plaintext: Data, key: Data)`.
    /// - Parameters:
    ///   - ciphertext: The ciphertext, which includes the authentication tag.
    ///   - key: The shared key, as obtained with `generateSharedKey(pubKey: Data, privKey: Data)`.
    ///   - version: The version. This is currently used to determine whether the message is padded. If greater than 0, the message will be unpadded after decryption.
    /// - Throws: `CryptoError.decryption`, either when message does not have the right length or libsodium fails to decrypt.
    /// - Returns: The plaintext data.
    func decrypt(_ ciphertext: Data, key: Data, version: Int) throws -> Data {
        guard ciphertext.count > sodium.box.NonceBytes else {
            throw CryptoError.decryption
        }
        guard var plaintext: Bytes = sodium.box.open(nonceAndAuthenticatedCipherText: ciphertext.bytes, beforenm: key.bytes) else {
            throw CryptoError.decryption
        }
        if version > 0 {
            sodium.utils.unpad(bytes: &plaintext, blockSize: paddingBlockSize)
        }

        return plaintext.data
    }

    // MARK: - Hash functions

    /// Create a Blake2b hash on data.
    /// - Parameter data: The data that should be hashed
    /// - Throws: `CryptoError.hashing` when libsodium fails to calculate the hash.
    /// - Returns: The hash data.
    func hash(_ data: Data) throws -> Data {
        guard let hashData = sodium.genericHash.hash(message: data.bytes) else {
            throw CryptoError.hashing
        }

        return hashData.data
    }

    /// Create a Blake2b hash on a string and return the hex-encoded hash string.
    /// - Parameter data: The string that should be hashed
    /// - Throws: `CryptoError.hashing` when libsodium fails to calculate the hash.
    /// - Returns: The hex-encoded string.
    func hash(_ message: String) throws -> String {
        let hashData = try hash(message.data)

        guard let hash = sodium.utils.bin2hex(hashData.bytes) else {
            throw CryptoError.convertToHex
        }

        return hash
    }

    /// Create a SHA256 hash on a string and return the hex-encoded hash string.
    /// - Parameter data: The string that should be hashed
    /// - Returns: The hex-encoded string.
    func sha256(from string: String) -> String {
        let digest = sha256(from: string.data(using: String.Encoding.utf8)!)
        let hexBytes = digest.map { String(format: "%02hhx", $0) }
        return hexBytes.joined()
    }

    /// Create a SHA256 hash on data.
    /// - Parameter data: The data that should be hashed
    /// - Returns: The hash data.
    func sha256(from data: Data) -> Data {
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        _ = digest.withUnsafeMutableBytes { digestBytes in
            data.withUnsafeBytes { CC_SHA256($0.baseAddress, CC_LONG(data.count), digestBytes.bindMemory(to: UInt8.self).baseAddress) }
        }
        return digest.data
    }

    /// Checks that two Data objects have the same content, without leaking information about the actual content of these objects.
    /// - Parameters:
    ///   - first: The first data object
    ///   - second: The second data object
    /// - Returns: The result
    func equals(first: Data, second: Data) -> Bool {
        return sodium.utils.equals(first.bytes, second.bytes)
    }
}
