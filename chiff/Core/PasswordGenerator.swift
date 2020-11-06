//
//  PasswordGenerator.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import Foundation
import LocalAuthentication

enum PasswordGenerationError: Error {
    case characterNotAllowed
    case tooShort
    case tooLong
    case keyGeneration
    case invalidPassword
    case ppdInconsistency
}

/// Deterministically passwords with or without a PPD.
class PasswordGenerator {

    static let cryptoContext = "keynpass"

    let seed: Data
    let username: String
    let siteId: String
    let ppd: PPD?
    let characters: [Character]
    let version: Int

    /**
     A password generator can be used to generate password or calulcate offsets.

     - Parameters:
        - username: The username is used to determine the key from which the password is derived.
        - siteId: The siteId is used to determine the key from which the password is derived.
        - ppd: A PPD can be provided to generate a password according to the rules of the PPD.
        - passwordSeed: The seed from which the key for the password should be derived.
        - version: For backwards compatibility, the version can be provided to re-generate password that used an older version of the algorithm. Defaults to the current version
     */
    init(username: String, siteId: String, ppd: PPD?, passwordSeed: Data, version: Int = 1) {
        self.username = username
        self.siteId = siteId
        self.ppd = ppd
        self.seed = passwordSeed
        self.version = version
        if let characterSets = ppd?.characterSets {
            if ppd?.version == .v1_0 {
                self.characters = characterSets.reduce([Character](), { $1.characters != nil ? $0 + $1.characters!.sorted() : $0 })
                return
            } else {
                self.characters = characterSets.reduce(Set<Character>(), { (characters, characterSet) in
                    var chars = characters
                    if let baseCharacters = characterSet.base?.characters {
                        chars.formUnion(baseCharacters.sorted())
                    }
                    if let additionalCharacters = characterSet.characters {
                        chars.formUnion(additionalCharacters.sorted())
                    }
                    return chars
                }).sorted()
            }
        } else {
            self.characters = PasswordValidator.optimalCharacterSet.sorted()
        }
    }

    /**
     Generates a password from the provided index. The provided index is not necessarily the same index as the one that will be
     used to generate the password, because restrictions from the PPD may apply.

     - Parameters:
        - index: The index that is used to generate the password.
        - offset: The offset that should be applied to the key before generating the password.

     - Returns: A tuple of the password and the index.
     - Postcondition: The returned index is higher or equal to the provided index.
     */
    func generate(index passwordIndex: Int, offset: [Int]?) throws -> (String, Int) {
        let length = self.length(isCustomPassword: offset != nil)
        guard length >= PasswordValidator.minPasswordLength else {
            throw PasswordGenerationError.tooShort
        }

        var index = passwordIndex
        var password = try generatePasswordCandidate(index: index, length: length, offset: offset)

        if offset == nil { // Only validate generated password. Custom passwords should be validated in UI.
            let passwordValidator = PasswordValidator(ppd: ppd)
            while try !passwordValidator.validate(password: password) {
                index += 1
                password = try generatePasswordCandidate(index: index, length: length, offset: offset)
            }
        }

        return (password, index)
    }

    /**
     Generates an offset for the provided password. The offset can be used to generate user-chosen passwords using the deterministic
     algorithm

     - Parameters:
        - index: The index that is used to generate the password.
        - password: The password.

     - Returns: The password offset as list of numbers, where each number is byte: `0 <= n <= 255`.
     */
    func calculateOffset(index passwordIndex: Int, password: String) throws -> [Int] {
        let chars = PasswordValidator.allCharacterSet.sorted()
        let length = self.length(isCustomPassword: true)
        let validator = PasswordValidator(ppd: ppd)
        guard password.count <= 100 else {
            throw PasswordGenerationError.tooLong
        }
        guard validator.validateCharacters(password: password, characters: String(chars)) else {
            throw PasswordGenerationError.characterNotAllowed
        }

        let key = try generateKey(index: passwordIndex)
        let bitLength = length * Int(ceil(log2(Double(chars.count)))) + (128 + length - (128 % length))
        let byteLength = roundUp(bitLength, (length * 8)) / 8
        let keyData = try Crypto.shared.deterministicRandomBytes(seed: key, length: byteLength)

        let characters = Array(password)
        return (0..<length).map({ (index) -> Int in
            // This assumes only characters from ppd.chars are used, will fail otherwise. This is checked in guard statement above.
            let charIndex = index < characters.count ? chars.firstIndex(of: characters[index])! : chars.count
            return (charIndex - keyData[index..<index + (byteLength / length)].reduce(0) { ($0 << 8 + Int($1)) %% (chars.count + 1) }) %% (chars.count + 1)
        })
    }

    // MARK: - Private functions

    /// The password length. Depends on PPD or default value if no PPD is provided
    private func length(isCustomPassword: Bool) -> Int {
        var length = isCustomPassword ? PasswordValidator.maxPasswordLength : PasswordValidator.fallbackPasswordLength
        let chars = isCustomPassword ? PasswordValidator.allCharacterSet.sorted() : characters
        if let maxLength = ppd?.properties?.maxLength {
            length = maxLength < PasswordValidator.maxPasswordLength ? min(maxLength, PasswordValidator.maxPasswordLength) : Int(ceil(128/log2(Double(chars.count))))
        }
        return length
    }

    /// Generates a password candidate, for a given index.
    private func generatePasswordCandidate(index passwordIndex: Int, length: Int, offset: [Int]?) throws -> String {
        let chars = offset != nil ? PasswordValidator.allCharacterSet.sorted() : characters
        let key = try generateKey(index: passwordIndex)
        let bitLength = length * Int(ceil(log2(Double(chars.count)))) + (128 + length - (128 % length))
        let byteLength = roundUp(bitLength, (length * 8)) / 8 // Round to nearest multiple of L * 8, so we can use whole bytes
        let keyData = try Crypto.shared.deterministicRandomBytes(seed: key, length: byteLength)
        let modulus = offset == nil ? chars.count : chars.count + 1
        let offset = offset ?? [Int](repeatElement(0, count: length))

        return (0..<length).reduce("") { (password, index) -> String in
            let charIndex = (keyData[index..<index + (byteLength / length)].reduce(0) { ($0 << 8 + Int($1)) %% modulus } + offset[index]) %% modulus
            return charIndex == chars.count ? password : password + String(chars[charIndex])
        }
    }

    private func roundUp(_ n: Int, _ m: Int) -> Int {
        return n >= 0 ? ((n + m - 1) / m) * m : (n / m) * m
    }

    private func generateKey(index passwordIndex: Int) throws -> Data {
        var value: UInt64 = 0
        _ = withUnsafeMutableBytes(of: &value, { version == 0 ? siteId.sha256.data.copyBytes(to: $0, from: 0..<8) : siteId.sha256Data.copyBytes(to: $0, from: 0..<8) })

        let siteKey = try Crypto.shared.deriveKey(keyData: seed, context: PasswordGenerator.cryptoContext, index: value)
        let key = try Crypto.shared.deriveKey(keyData: siteKey, context: String(version == 0 ? username.sha256.prefix(8) : username.sha256Data.base64.prefix(8)), index: UInt64(passwordIndex))
        return key
    }

}
