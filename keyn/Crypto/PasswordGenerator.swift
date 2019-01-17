//
//  PasswordGenerator.swift
//  keyn
//
//  Created by bas on 15/03/2018.
//  Copyright © 2018 keyn. All rights reserved.
//

import Foundation

enum PasswordGenerationError: Error {
    case characterNotAllowed
    case tooShort
    case keyGeneration
    case dataConversion
    case invalidPassword
}


class PasswordGenerator {

    static let sharedInstance = PasswordGenerator()
    private init() {} //This prevents others from using the default '()' initializer for this singleton class.


    func generatePassword(username: String, passwordIndex: Int, siteID: String, ppd: PPD?, offset: [Int]?) throws -> (String, Int) {
        let (length, chars) = parse(ppd: ppd, customPassword: offset != nil)

        guard length >= PasswordValidator.MIN_PASSWORD_LENGTH_BOUND else {
            throw PasswordGenerationError.tooShort
        }

        var index = passwordIndex
        var password = try generatePasswordCandidate(username: username, passwordIndex: index, siteID: siteID, length: length, chars: chars, offset: offset)
        if offset == nil { // Only validate generated password. Custom passwords should be validated in UI.
            let passwordValidator = PasswordValidator(ppd: ppd)
            while !passwordValidator.validate(password: password) {
                index += 1
                password = try generatePasswordCandidate(username: username, passwordIndex: index, siteID: siteID, length: length, chars: chars, offset: offset)
            }
        }
        
        return (password, index)
    }

    func calculatePasswordOffset(username: String, passwordIndex: Int, siteID: String, ppd: PPD?, password: String) throws -> [Int] {
        // TODO: Check if this is OK. Not validating custom passwords
        let validator = PasswordValidator(ppd: ppd)
        guard validator.validateMaxLength(password: password) else {
            throw PasswordGenerationError.invalidPassword
        }
        guard validator.validateCharacters(password: password) else {
            throw PasswordGenerationError.characterNotAllowed
        }

        let (length, chars) = parse(ppd: ppd, customPassword: true)
        let key = try generateKey(username: username, passwordIndex: passwordIndex, siteID: siteID)
        let bitLength = length * Int(ceil(log2(Double(chars.count)))) + (128 + length - (128 % length))
        let byteLength = roundUp(n: bitLength, m: (length * 8)) / 8
        let keyData = try Crypto.sharedInstance.deterministicRandomBytes(seed: key, length: byteLength)
        
        let characters = Array(password)
        return (0..<length).map({ (index) -> Int in
            let charIndex = index < characters.count ? chars.index(of: characters[index]) ?? chars.count : chars.count // This assumes only characters from ppd.chars are used, will print wrong password otherwise. This is check in guard statement above.
            return (charIndex - keyData[index..<index + (byteLength / length)].reduce(0) { ($0 << 8 + Int($1)).mod(n: chars.count + 1) }).mod(n: chars.count + 1)
        })
        
    }


    // MARK: Private functions
    
    private func parse(ppd: PPD?, customPassword: Bool) -> (Int, [Character]) {
        var length = customPassword ? PasswordValidator.MAX_PASSWORD_LENGTH_BOUND : PasswordValidator.FALLBACK_PASSWORD_LENGTH
        var chars = [Character]()
        
        if let characterSets = ppd?.characterSets {
            for characterSet in characterSets {
                if let characters = characterSet.characters {
                    chars.append(contentsOf: characters.sorted())
                }
            }
        } else {
            chars.append(contentsOf: PasswordValidator.OPTIMAL_CHARACTER_SET.sorted()) // Optimal character set
        }
        
        if let maxLength = ppd?.properties?.maxLength {
            length = maxLength < PasswordValidator.MAX_PASSWORD_LENGTH_BOUND ? min(maxLength, PasswordValidator.MAX_PASSWORD_LENGTH_BOUND) : Int(ceil(128/log2(Double(chars.count))))
        }
        
        return (length, chars)
    }

    private func generatePasswordCandidate(username: String, passwordIndex: Int, siteID: String, length: Int, chars: [Character], offset: [Int]?) throws -> String {
        let key = try generateKey(username: username, passwordIndex: passwordIndex, siteID: siteID)
        let bitLength = length * Int(ceil(log2(Double(chars.count)))) + (128 + length - (128 % length))
        let byteLength = roundUp(n: bitLength, m: (length * 8)) / 8 // Round to nearest multiple of L * 8, so we can use whole bytes
        let keyData = try Crypto.sharedInstance.deterministicRandomBytes(seed: key, length: byteLength)
        let modulus = offset == nil ? chars.count : chars.count + 1
        let offset = offset ?? Array<Int>(repeatElement(0, count: length))

        return (0..<length).reduce("") { (pw, index) -> String in
            let charIndex = (keyData[index..<index + (byteLength / length)].reduce(0) { ($0 << 8 + Int($1)).mod(n: modulus) } + offset[index]).mod(n: modulus)
            return charIndex == chars.count ? pw : pw + String(chars[charIndex])
        }
    }

    private func roundUp(n: Int, m: Int) -> Int {
        return n >= 0 ? ((n + m - 1) / m) * m : (n / m) * m
    }

    private func generateKey(username: String, passwordIndex: Int, siteID: String) throws -> Data {
        guard let usernameData = username.data(using: .utf8),
            let siteData = siteID.prefix(8).data(using: .utf8) else {
                throw PasswordGenerationError.dataConversion
        }
        
        // TODO: SiteData is now a constant. Should we use a variable (besides the siteID as index?)
        let siteKey = try Crypto.sharedInstance.deriveKey(keyData: Seed.getPasswordSeed(), context: siteData, index: 0)
        let key = try Crypto.sharedInstance.deriveKey(keyData: siteKey, context: usernameData, index: passwordIndex)

        return key
    }
    
}
