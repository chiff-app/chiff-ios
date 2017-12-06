import Foundation
import CryptoSwift
import Sodium

enum CryptoError: Error {
    case randomGeneration
    case base64Decoding
    case base64Encoding
    case hkdfInput
    case keyGeneration
    case keyDerivation
    case encryption
    case decryption
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
        let key = try hkdf(username: username, passwordIndex: passwordIndex, siteID: siteID)
        let key2 = try deriveKey(username: username, passwordIndex: passwordIndex, siteID: siteID)
        
        // Convert key2 to password
        var password2 = ""
        for (_, element) in key2.enumerated() {
            let index = Int(element) % chars.count
            password2 += String(chars[index])
            if password2.count >= restrictions.length { break }
        }
        
        // Convert key to password
        var password = ""
        for (_, element) in key.enumerated() {
            let index = Int(element) % chars.count
            password += String(chars[index])
            if password.count >= restrictions.length { break }
        }
        print("HKDF_password: \(password)")
        print("Sodium_password: \(password2)")
        
        return password
    }
    
    // TODO: choose between HKDF and deriveKey
    private func deriveKey(username: String, passwordIndex: Int, siteID: String, keyLengthBytes: Int = 32) throws ->  Data {
        let seed = try Seed.get()
        
        guard let contextData = "\(username)_\(siteID)".data(using: .utf8),
            let contextHash = sodium.genericHash.hash(message: contextData, outputLength: 8),
            let context = sodium.utils.bin2base64(contextHash, variant: .ORIGINAL_NO_PADDING), // Is this OK or should hash be converted to string otherwise to maximise entropy in context?
            let key = sodium.keyDerivation.derive(secretKey: seed, index: UInt64(passwordIndex), length: keyLengthBytes, context: String(context.prefix(8))) else {
                throw CryptoError.keyDerivation
        }

        return key
    }

    private func hkdf(username: String, passwordIndex: Int, siteID: String, keyLengthBytes: Int = 32) throws -> Data {
        let seed = try Seed.get()
        guard let accountInput = (username + siteID + String(passwordIndex)).data(using: .utf8) else {
            throw CryptoError.hkdfInput
        }

        // Extract
        // TODO: use salt?
        let salt = Data().bytes
        let prk = try HMAC(key: salt, variant: .sha256).authenticate(seed.bytes)

        // Expand
        let hashLength = 32
        let iterations = Int(ceil(Double(keyLengthBytes) / Double(hashLength)))
        var block = [UInt8]()
        var okm = [UInt8]()

        for i in 1...iterations {
            var input = Array<UInt8>()
            input.append(contentsOf: block)
            input.append(contentsOf: accountInput.bytes)
            input.append(UInt8(i))
            block = try HMAC(key: prk, variant: .sha256).authenticate(input)
            okm.append(contentsOf: block)
        }
        
        return Data(bytes: okm[0..<keyLengthBytes])
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

    //This function should encrypt a password message with a browser public key
    func encrypt(_ plaintext: Data, pubKey : Box.PublicKey, privKey: Box.SecretKey) throws -> Data {
        guard let ciphertext: Data = sodium.box.seal(message: plaintext, recipientPublicKey: pubKey, senderSecretKey: privKey) else {
            throw CryptoError.encryption
        }
        return ciphertext
    }

    // This function should decrypt a password request with the sessions corresponding session / private key and check signature with browser's public key
    func decrypt(_ ciphertext: Data, privKey: Box.SecretKey, pubKey : Box.PublicKey) throws -> Data {
        guard let plaintext: Data = sodium.box.open(nonceAndAuthenticatedCipherText: ciphertext, senderPublicKey: pubKey, recipientSecretKey: privKey) else {
            throw CryptoError.decryption
        }
        return plaintext
    }
    
}
