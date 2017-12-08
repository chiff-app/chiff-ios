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
}


class Crypto {
    
    static let sharedInstance = Crypto()
    
    private let sodium = Sodium()
    private init() {} //This prevents others from using the default '()' initializer for this singleton class.

    /*
     * The first time we use the app, we need to generate the seed and put it in the
     * keychain. This function will need to be called in the setup process and from
     * the resulting seed all passwords will be generated.
     */
    func generateSeed() throws -> Data {

        // Generate random seed
        var seed = Data(count: 32)
        let seedGenerationStatus = seed.withUnsafeMutableBytes { mutableBytes in
            SecRandomCopyBytes(kSecRandomDefault, seed.count, mutableBytes)
        }
        guard seedGenerationStatus == errSecSuccess else {
            throw CryptoError.randomGeneration
        }

        return seed
    }


    func generatePassword(username: String, passwordIndex: Int, siteID: String, restrictions: PasswordRestrictions) throws -> String {
        var chars = [Character]()
        for character in restrictions.characters {
            // TODO: Check with other passwordmanagers how to split this out
            switch character {
            case .lower:
                chars.append(contentsOf: [Character]("abcdefghijklmnopqrstuvwxyz"))
            case .upper:
                chars.append(contentsOf: [Character]("ABCDEFGHIJKLMNOPQRSTUVWXYZ"))
            case .numbers:
                chars.append(contentsOf: [Character]("0123456789"))
            case .symbols:
                chars.append(contentsOf: [Character]("!@#$%^&*()_-+={[}]:;<,>.?/"))
            }
        }

        // Generate key from seed and parameters
        guard let usernameData = username.data(using: .utf8),
            let siteData = siteID.data(using: .utf8) else {
                throw CryptoError.keyDerivation
        }
        let key = try deriveKey(keyData: deriveKey(keyData: Seed.get(), context: siteData), context: usernameData, passwordIndex: passwordIndex)
        
        // Convert key to password
        guard let keyData = sodium.randomBytes.deterministic(length: restrictions.length, seed: key) else {
            throw CryptoError.keyDerivation
        }
        var password = ""
        for (_, element) in keyData.enumerated() {
            let index = Int(element) % chars.count
            password += String(chars[index])
        }
        
        return password
    }


    private func deriveKey(keyData: Data, context: Data, passwordIndex: Int = 0, keyLengthBytes: Int = 32) throws ->  Data {
        guard let contextHash = sodium.genericHash.hash(message: context, outputLength: 8),
            let context = sodium.utils.bin2base64(contextHash, variant: .ORIGINAL_NO_PADDING),
            let key = sodium.keyDerivation.derive(secretKey: keyData, index: UInt64(passwordIndex), length: keyLengthBytes, context: String(context.prefix(8))) else {
                throw CryptoError.keyDerivation
        }

        return key
    }

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

    func createSessionKeyPair() throws -> Box.KeyPair {
        guard let keyPair = sodium.box.keyPair() else {
            throw CryptoError.keyGeneration
        }

        return keyPair
    }

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

    func hash(_ message: String) throws -> String {
        guard let messageData = message.data(using: .utf8) else {
            throw CryptoError.convertToData
        }
        guard let hashData = sodium.genericHash.hash(message: messageData) else {
            throw CryptoError.hashing
        }
        guard let hash = sodium.utils.bin2hex(hashData) else {
            throw CryptoError.convertToHex
        }
        return hash
    }
    
}
