import Foundation
import Sodium

enum CryptoError: Error {
    case randomGeneration
    case base64Decoding
    case base64Encoding
    case keyGeneration
    case keyDerivation
    case encryption
    case decryption
    case convertToData
    case convertToHex
    case hashing
    case mnemonicConversion
    case mnemonicChecksum
}


class Crypto {
    
    static let sharedInstance = Crypto()
    
    private let sodium = Sodium()
    private let SEED_SIZE = 16
    private init() {} //This prevents others from using the default '()' initializer for this singleton class.


    // MARK: Key generation functions

    /*
     * The first time we use the app, we need to generate the seed and put it in the
     * keychain. This function will need to be called in the setup process and from
     * the resulting seed all passwords will be generated.
     */
    func generateSeed() throws -> Data {
        // Generate random seed
        // TODO: Should this be replaced by libsodium key generation function?
        var seed = Data(count: SEED_SIZE)
        let seedGenerationStatus = seed.withUnsafeMutableBytes { mutableBytes in
            SecRandomCopyBytes(kSecRandomDefault, SEED_SIZE, mutableBytes)
        }

        guard seedGenerationStatus == errSecSuccess else {
            throw CryptoError.randomGeneration
        }

        return seed
    }

    func deriveKeyFromSeed(seed: Data, keyType: KeyType, context: String) throws -> Data {
        // This expands the 128-bit seed to 256 bits by hashing. Necessary for key derivation.
        guard let seedHash = sodium.genericHash.hash(message: seed) else {
            throw CryptoError.hashing
        }
        
        // This derives a subkey from the seed for a given index and context
        guard let key = sodium.keyDerivation.derive(secretKey: seedHash, index: keyType.rawValue, length: 32, context: String(context.prefix(8))) else {
            throw CryptoError.keyDerivation
        }

        return key
    }


    func createSessionKeyPair() throws -> Box.KeyPair {
        guard let keyPair = sodium.box.keyPair() else {
            throw CryptoError.keyGeneration
        }

        return keyPair
    }

    func deterministicRandomBytes(seed: Data, length: Int) throws -> Data {
        guard let keyData = sodium.randomBytes.deterministic(length: length, seed: seed) else {
            throw CryptoError.keyDerivation
        }
        
        return keyData
    }


    func deriveKey(keyData: Data, context: Data, index: Int = 0, keyLengthBytes: Int = 32) throws ->  Data {
        guard let contextHash = sodium.genericHash.hash(message: context, outputLength: 8) else {
            throw CryptoError.hashing
        }
        guard let context = sodium.utils.bin2base64(contextHash, variant: .ORIGINAL_NO_PADDING) else {
            throw CryptoError.base64Encoding
        }
        guard let key = sodium.keyDerivation.derive(secretKey: keyData, index: UInt64(index), length: keyLengthBytes, context: String(context.prefix(8))) else {
            throw CryptoError.keyDerivation
        }

        return key
    }



    // MARK: Base64 conversion functions

    func convertFromBase64(from base64String: String) throws -> Data  {
        // Convert from base64 to Data
        guard let data = sodium.utils.base642bin(base64String, variant: .URLSAFE_NO_PADDING, ignore: nil) else {
            throw CryptoError.base64Decoding
        }

        return data
    }

    func convertToBase64(from data: Data) throws -> String  {
        // Convert from Data to base64
        guard let b64String = sodium.utils.bin2base64(data, variant: .URLSAFE_NO_PADDING) else {
            throw CryptoError.base64Encoding
        }

        return b64String
    }


    // MARK: Encryption & decryption functions

    func encrypt(_ plaintext: Data, pubKey: Box.PublicKey, privKey: Box.SecretKey) throws -> Data {
        guard let ciphertext: Data = sodium.box.seal(message: plaintext, recipientPublicKey: pubKey, senderSecretKey: privKey) else {
            throw CryptoError.encryption
        }
        return ciphertext
    }

    func encrypt(_ plaintext: Data, pubKey: Box.PublicKey) throws -> Data {
        guard let ciphertext: Data = sodium.box.seal(message: plaintext, recipientPublicKey: pubKey) else {
            throw CryptoError.encryption
        }
        return ciphertext
    }

    // This function should decrypt a password request with the sessions corresponding session / private key and check signature with browser's public key
    func decrypt(_ ciphertext: Data, privKey: Box.SecretKey, pubKey: Box.PublicKey) throws -> Data {
        guard let plaintext: Data = sodium.box.open(nonceAndAuthenticatedCipherText: ciphertext, senderPublicKey: pubKey, recipientSecretKey: privKey) else {
            throw CryptoError.decryption
        }
        return plaintext
    }


     // MARK: Hash functions

    func hash(_ data: Data) throws -> Data {
        guard let hashData = sodium.genericHash.hash(message: data) else {
            throw CryptoError.hashing
        }
        return hashData
    }

    func hash(_ message: String) throws -> String {
        guard let messageData = message.data(using: .utf8) else {
            throw CryptoError.convertToData
        }
        let hashData = try hash(messageData)
        guard let hash = sodium.utils.bin2hex(hashData) else {
            throw CryptoError.convertToHex
        }
        return hash
    }

}
