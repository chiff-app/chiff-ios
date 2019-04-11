/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import Foundation

enum PasswordGenerationError: KeynError {
    case characterNotAllowed
    case tooShort
    case keyGeneration
    case invalidPassword
}

class PasswordGenerator {

    let username: String
    let siteId: String
    let ppd: PPD?

    var characters: [Character] {
        if let characterSets = ppd?.characterSets {
            return characterSets.reduce([Character](), { (result, characterSet) -> [Character] in
                if let characters = characterSet.characters {
                    return result + characters.sorted()
                } else {
                    return result
                }
            })
        } else {
            return PasswordValidator.OPTIMAL_CHARACTER_SET.sorted()
        }
    }

    init(username: String, siteId: String, ppd: PPD?) {
        self.username = username
        self.siteId = siteId
        self.ppd = ppd
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
            while !passwordValidator.validate(password: password) {
                index += 1
                password = try generatePasswordCandidate(index: index, length: length, offset: offset)
            }
        }
        
        return (password, index)
    }

    func calculateOffset(index passwordIndex: Int, password: String) throws -> [Int] {
        #warning("TODO: Check if this is OK. Not validating custom passwords.")
        let chars = PasswordValidator.MAXIMAL_CHARACTER_SET.sorted()
        let length = self.length(isCustomPassword: true)
        let validator = PasswordValidator(ppd: ppd)
        guard validator.validateMaxLength(password: password) else {
            throw PasswordGenerationError.invalidPassword
        }

        let key = try generateKey(index: passwordIndex)
        let bitLength = length * Int(ceil(log2(Double(chars.count)))) + (128 + length - (128 % length))
        let byteLength = roundUp(n: bitLength, m: (length * 8)) / 8
        let keyData = try Crypto.shared.deterministicRandomBytes(seed: key, length: byteLength)
        
        let characters = Array(password)
        return (0..<length).map({ (index) -> Int in
            // This assumes only characters from ppd.chars are used, will print wrong password otherwise. This is check in guard statement above.
            let charIndex = index < characters.count ? chars.index(of: characters[index]) ?? chars.count : chars.count 
            return (charIndex - keyData[index..<index + (byteLength / length)].reduce(0) { ($0 << 8 + Int($1)).mod(chars.count + 1) }).mod(chars.count + 1)
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
            let charIndex = (keyData[index..<index + (byteLength / length)].reduce(0) { ($0 << 8 + Int($1)).mod(modulus) } + offset[index]).mod(modulus)
            return charIndex == chars.count ? pw : pw + String(chars[charIndex])
        }
    }

    private func roundUp(n: Int, m: Int) -> Int {
        return n >= 0 ? ((n + m - 1) / m) * m : (n / m) * m
    }

    private func generateKey(index passwordIndex: Int) throws -> Data {
        #warning("TODO: write migration script to get rid of prefix")
        let siteKey = try Crypto.shared.deriveKey(keyData: Seed.getPasswordSeed(), context: String(self.siteId.prefix(8)).data, index: 0)
        let key = try Crypto.shared.deriveKey(keyData: siteKey, context: username.data, index: passwordIndex)

        return key
    }
}
