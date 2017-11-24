import Foundation
import CryptoSwift
import Sodium

enum CryptoError: Error {
    case randomGeneration
    case base64Decoding
    case hkdfInput
    case keyGeneration
    case encryption
}


class Crypto {


    /*
     * The first time we use the app, we need to generate the seed and put it in the
     * keychain. This function will need to be called in the setup process and from
     * the resulting seed all passwords will be generated.
     */
    class func generateSeed() throws {

        // Generate random seed
        var seed = Data(count: 32)
        let seedGenerationStatus = seed.withUnsafeMutableBytes { mutableBytes in
            SecRandomCopyBytes(kSecRandomDefault, seed.count, mutableBytes)
        }
        guard seedGenerationStatus == errSecSuccess else {
            throw CryptoError.randomGeneration
        }

        // Store key
        // TODO: Should seed be stored by this class or by caller?
        try Keychain.saveSeed(seed: seed)
    }


    class func generatePassword(username: String, passwordIndex: Int, siteID: String, restrictions: PasswordRestrictions) throws -> String {
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


        // Convert key to password
        var password = ""
        for (_, element) in key.enumerated() {
            let index = Int(element) % chars.count
            password += String(chars[index])
        }

        return String(password.prefix(restrictions.length))
    }

    private class func hkdf(username: String, passwordIndex: Int, siteID: String, keyLengthBytes: Int = 32) throws -> Data {
        let seed = try Keychain.getSeed()
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

    class func convertPublicKey(from base64EncodedKey: String) throws -> Box.PublicKey  {
        // Convert from base64 to Data

        let sodium = Sodium()
        guard let pkData = sodium.utils.base642bin(base64EncodedKey, variant: .URLSAFE_NO_PADDING, ignore: nil) else {
            throw CryptoError.base64Decoding
        }

        return pkData
    }

    class func createSessionKeyPair() throws -> Box.KeyPair {
        let sodium = Sodium()
        let keyPair = sodium.box.keyPair()

        guard keyPair != nil else {
            throw CryptoError.keyGeneration
        }

        return keyPair!
    }

    // This function should encrypt a password message with a browser public key
    class func encrypt(_ message: Data, with id: String) throws -> Data {

        let sodium = Sodium()

        let pubBrowserKey = try Keychain.getBrowserSessionKey(with: Session.KeyIdentifier.browser.identifier(for: id))
        let secretAppKey = try Keychain.getAppSessionKey(with: Session.KeyIdentifier.priv.identifier(for: id))

        guard let ciphertext: Data = sodium.box.seal(message: message, recipientPublicKey: pubBrowserKey, senderSecretKey: secretAppKey) else {
            throw CryptoError.encryption
        }

        return ciphertext

    }

    class func decrypt(with privKeyID: String) -> String {
        // This function should decrypt a password request with the sessions corresponding session / private key
        return "TODO"
    }
    
}
