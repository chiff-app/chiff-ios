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
    case characterNotAllowed
    case passwordGeneration
}


class Crypto {
    
    static let sharedInstance = Crypto()
    
    private let sodium = Sodium()
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
        var seed = Data(count: 16)

        let seedGenerationStatus = seed.withUnsafeMutableBytes { mutableBytes in
            SecRandomCopyBytes(kSecRandomDefault, seed.count, mutableBytes)
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


    // MARK: Password generation functions

    func generatePassword(username: String, passwordIndex: Int, siteID: String, ppd: PPD?, offset: [Int]?) throws -> String {

        var length = 22
        var chars = [Character]()
        if let ppd = ppd, let properties = ppd.properties, let maxLength = properties.maxLength, let minLength = properties.minLength, let characterSets = ppd.characterSets {
            // Get parameters from ppd
            length = min(maxLength, 24)

            // If the password is less then 8 characters, current password generation may result in a integer overflow. Perhaps should be checked somewhere else.
            guard length >= 8 else {
                throw CryptoError.passwordGeneration
            }

            for characterSet in characterSets {
                if let characters = characterSet.characters {
                    chars.append(contentsOf: [Character](characters))
                }
            }
        } else {
            // Use optimal fallback composition rules
            length = 22 // redundant, but for now for clarity
        }

        let key = try generateKey(username: username, passwordIndex: passwordIndex, siteID: siteID)

        // #bits N = L x ceil(log2(C)) + (128 + L - (128 % L), where L is password length and C is character set cardinality, see Horsch(2017), p90
        let bitLength = length * Int(ceil(log2(Double(chars.count)))) + (128 + length - (128 % length))
        let byteLength = roundUp(n: bitLength, m: (length * 8)) / 8 // Round to nearest multiple of L * 8, so we can use whole bytes
        guard let keyData = sodium.randomBytes.deterministic(length: byteLength, seed: key) else {
            throw CryptoError.keyDerivation
        }

        // Zero-offsets if no offset is given
        let modulus = offset == nil ? chars.count : chars.count + 1
        let offset = offset ?? Array<Int>(repeatElement(0, count: length))
        let bytesPerChar = byteLength / length
        var keyDataIterator = keyData.makeIterator()
        var password = ""

        // Generates the password
        for index in 0..<length {
            var data = Data()
            var counter = 0

            // Add up bytevalues to value
            repeat {
                guard let byte = keyDataIterator.next() else {
                    throw CryptoError.keyGeneration
                }
                data.append(byte)
                counter += 1
            } while counter < bytesPerChar

            // Choose character from value, taking offset into account
            let value: Int = data.withUnsafeBytes { $0.pointee }
            let characterValue = (value + offset[index]) % modulus
            if characterValue != chars.count {
                password += String(chars[characterValue])
            }
        }

        // TODO: Implement rejection sampling.

        return password
    }

    
    func calculatePasswordOffset(username: String, passwordIndex: Int, siteID: String, ppd: PPD?, password: String) throws -> [Int] {

        // TODO: We should check first if password complies with PPD, otherwise throw error. Or use different function so custom passwords can be verified while typing

        var length = 22
        var chars = [Character]()
        if let ppd = ppd, let properties = ppd.properties, let maxLength = properties.maxLength, let minLength = properties.minLength, let characterSets = ppd.characterSets {
            // Get parameters from ppd
            length = min(maxLength, 24)

            // If the password is less then 8 characters, current password generation may result in a integer overflow. Perhaps should be checked somewhere else.
            guard length >= 8 else {
                throw CryptoError.passwordGeneration
            }

            for characterSet in characterSets {
                if let characters = characterSet.characters {
                    chars.append(contentsOf: [Character](characters))
                }
            }
        } else {
            // Use optimal fallback composition rules
            length = 22 // redundant, but for now for clarity
        }

        var characterIndices = [Int](repeatElement(chars.count, count: length))
        var index = 0

        // This is part of validating password: checking for disallowed characters
        for char in password {
            guard let characterIndex = chars.index(of: char) else {
                throw CryptoError.characterNotAllowed
            }
            characterIndices[index] = characterIndex
            index += 1
        }

        let key = try generateKey(username: username, passwordIndex: passwordIndex, siteID: siteID)

        let bitLength = length * Int(ceil(log2(Double(chars.count)))) + (128 + length - (128 % length))
        let byteLength = roundUp(n: bitLength, m: (length * 8)) / 8
        guard let keyData = sodium.randomBytes.deterministic(length: byteLength, seed: key) else {
            throw CryptoError.keyDerivation
        }

        let bytesPerChar = byteLength / length
        var keyDataIterator = keyData.makeIterator()
        var offsets = [Int]()

        // Generates the offset
        for index in 0..<length {
            var data = Data()
            var counter = 0

            // Add up bytevalues to value
            repeat {
                guard let byte = keyDataIterator.next() else {
                    throw CryptoError.keyGeneration
                }
                data.append(byte)
                counter += 1
            } while counter < bytesPerChar

            // Calculate offset and add to array
            let value: Int = data.withUnsafeBytes { $0.pointee }
            offsets.append((characterIndices[index] - value) % (chars.count + 1))
        }
        
        return offsets
    }


    // MARK: Private functions

    private func roundUp(n: Int, m: Int) -> Int {
        return n >= 0 ? ((n + m - 1) / m) * m : (n / m) * m
    }
    
    private func restrictionCharacterArray(restrictions: PasswordRestrictions) -> [Character] {
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
        
        return chars
    }

    private func generateKey(username: String, passwordIndex: Int, siteID: String) throws -> Data {
        guard let usernameData = username.data(using: .utf8),
            let siteData = siteID.data(using: .utf8) else {
                throw CryptoError.keyDerivation
        }

        // TODO: If siteID is Int, use that as index. siteData is then not necessary anymore.
        let siteKey = try deriveKey(keyData: Seed.getPasswordKey(), context: siteData)
        let key = try deriveKey(keyData: siteKey, context: usernameData, passwordIndex: passwordIndex)
        
        return key
    }

    private func deriveKey(keyData: Data, context: Data, passwordIndex: Int = 0, keyLengthBytes: Int = 32) throws ->  Data {
        guard let contextHash = sodium.genericHash.hash(message: context, outputLength: 8) else {
            throw CryptoError.hashing
        }
        guard let context = sodium.utils.bin2base64(contextHash, variant: .ORIGINAL_NO_PADDING) else {
            throw CryptoError.base64Encoding
        }
        guard let key = sodium.keyDerivation.derive(secretKey: keyData, index: UInt64(passwordIndex), length: keyLengthBytes, context: String(context.prefix(8))) else {
            throw CryptoError.keyDerivation
        }
        
        return key
    }

}
