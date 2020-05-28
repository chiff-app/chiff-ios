/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import Foundation
import LocalAuthentication

enum PasswordGenerationError: KeynError {
    case characterNotAllowed
    case tooShort
    case keyGeneration
    case invalidPassword
    case ppdInconsistency
}

class PasswordGenerator {

    static let CRYPTO_CONTEXT = "keynpass"

    let seed: Data
    let username: String
    let siteId: String
    let ppd: PPD?
    let characters: [Character]
    let version: Int

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
            self.characters = PasswordValidator.OPTIMAL_CHARACTER_SET.sorted()
        }
    }

    func generate(index passwordIndex: Int, offset: [Int]?) throws -> (String, Int) {
        let length = self.length(isCustomPassword: offset != nil)
        guard length >= PasswordValidator.MIN_PASSWORD_LENGTH_BOUND else {
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

    func calculateOffset(index passwordIndex: Int, password: String) throws -> [Int] {
        let chars = PasswordValidator.MAXIMAL_CHARACTER_SET.sorted()
        let length = self.length(isCustomPassword: true)
        let validator = PasswordValidator(ppd: ppd)
        guard validator.validateMaxLength(password: password) else {
            throw PasswordGenerationError.invalidPassword
        }
        guard validator.validateCharacters(password: password, characters: String(chars)) else {
            throw PasswordGenerationError.characterNotAllowed
        }

        let key = try generateKey(index: passwordIndex)
        let bitLength = length * Int(ceil(log2(Double(chars.count)))) + (128 + length - (128 % length))
        let byteLength = roundUp(n: bitLength, m: (length * 8)) / 8
        let keyData = try Crypto.shared.deterministicRandomBytes(seed: key, length: byteLength)
        
        let characters = Array(password)
        return (0..<length).map({ (index) -> Int in
            // This assumes only characters from ppd.chars are used, will fail otherwise. This is checked in guard statement above.
            let charIndex = index < characters.count ? chars.firstIndex(of: characters[index])! : chars.count
            return (charIndex - keyData[index..<index + (byteLength / length)].reduce(0) { ($0 << 8 + Int($1)) %% (chars.count + 1) }) %% (chars.count + 1)
        })
    }

    // MARK: - Private

    private func length(isCustomPassword: Bool) -> Int {
        var length = isCustomPassword ? PasswordValidator.MAX_PASSWORD_LENGTH_BOUND : PasswordValidator.FALLBACK_PASSWORD_LENGTH
        let chars = isCustomPassword ? PasswordValidator.MAXIMAL_CHARACTER_SET.sorted() : characters
        if let maxLength = ppd?.properties?.maxLength {
            length = maxLength < PasswordValidator.MAX_PASSWORD_LENGTH_BOUND ? min(maxLength, PasswordValidator.MAX_PASSWORD_LENGTH_BOUND) : Int(ceil(128/log2(Double(chars.count))))
        }
        return length
    }

    private func generatePasswordCandidate(index passwordIndex: Int, length: Int, offset: [Int]?) throws -> String {
        let chars = offset != nil ? PasswordValidator.MAXIMAL_CHARACTER_SET.sorted() : characters
        let key = try generateKey(index: passwordIndex)
        let bitLength = length * Int(ceil(log2(Double(chars.count)))) + (128 + length - (128 % length))
        let byteLength = roundUp(n: bitLength, m: (length * 8)) / 8 // Round to nearest multiple of L * 8, so we can use whole bytes
        let keyData = try Crypto.shared.deterministicRandomBytes(seed: key, length: byteLength)
        let modulus = offset == nil ? chars.count : chars.count + 1
        let offset = offset ?? Array<Int>(repeatElement(0, count: length))

        return (0..<length).reduce("") { (pw, index) -> String in
            let charIndex = (keyData[index..<index + (byteLength / length)].reduce(0) { ($0 << 8 + Int($1)) %% modulus } + offset[index]) %% modulus
            return charIndex == chars.count ? pw : pw + String(chars[charIndex])
        }
    }

    private func roundUp(n: Int, m: Int) -> Int {
        return n >= 0 ? ((n + m - 1) / m) * m : (n / m) * m
    }

    private func generateKey(index passwordIndex: Int) throws -> Data {
        var value: UInt64 = 0
        _ = withUnsafeMutableBytes(of: &value, { version == 0 ? siteId.sha256.data.copyBytes(to: $0, from: 0..<8) : siteId.sha256Data.copyBytes(to: $0, from: 0..<8) } )

        let siteKey = try Crypto.shared.deriveKey(keyData: seed, context: PasswordGenerator.CRYPTO_CONTEXT, index: value)
        let key = try Crypto.shared.deriveKey(keyData: siteKey, context: String(version == 0 ? username.sha256.prefix(8) : username.sha256Data.base64.prefix(8)), index: UInt64(passwordIndex))
        return key
    }

}
