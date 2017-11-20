import Foundation
import CryptoSwift

enum CryptoError: Error {
    case randomGeneration
    case base64Decoding
    case hkdfInput
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
                chars.append(contentsOf: [Character]("abcdefghijklmnopqrstuvwxyz".characters))
            case .upper:
                chars.append(contentsOf: [Character]("ABCDEFGHIJKLMNOPQRSTUVWXYZ".characters))
            case .numbers:
                chars.append(contentsOf: [Character]("0123456789".characters))
            case .symbols:
                chars.append(contentsOf: [Character]("!@#$%^&*()_-+={[}]:;<,>.?/".characters))
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

    class func convertPublicKey(from base64EncodedKey: String) throws -> SecKey {
        // Convert from base64 to Data
        guard let pkData = Data.init(base64Encoded: base64EncodedKey) else {
            throw CryptoError.base64Decoding
        }

        // Create SecKey item
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeyClass as String: kSecAttrKeyClassPublic,
            kSecAttrKeySizeInBits as String: 256
        ]

        var error: Unmanaged<CFError>?

        guard let publicKey = SecKeyCreateWithData(pkData as CFData, attributes as CFDictionary, &error) else {
            throw error!.takeRetainedValue() as Error
        }

        return publicKey
    }


    class func encrypt(_ message: String, with pubKeyID: String) {
        // This function should encrypt a password message with a browser public key
    }

    class func decrypt(with privKeyID: String) -> String {
        // This function should decrypt a password request with the sessions corresponding session / private key
        return "TODO"
    }
    
}
