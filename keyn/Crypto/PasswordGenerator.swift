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
//        guard PasswordValidator(ppd: ppd).validate(password: password) else {
//            // This shouldn't happen if we properly check the custom password in the UI
//            throw PasswordGenerationError.invalidPassword
//        }

        let (length, chars) = parse(ppd: ppd, customPassword: true)

        var characterIndices = [Int](repeatElement(chars.count, count: length))
        var index = 0

        for char in password {
            guard let characterIndex = chars.index(of: char) else {
                throw PasswordGenerationError.characterNotAllowed
            }
            characterIndices[index] = characterIndex
            index += 1
        }

        let key = try generateKey(username: username, passwordIndex: passwordIndex, siteID: siteID)

        let bitLength = length * Int(ceil(log2(Double(chars.count)))) + (128 + length - (128 % length))
        let byteLength = roundUp(n: bitLength, m: (length * 8)) / 8
        let keyData = try Crypto.sharedInstance.deterministicRandomBytes(seed: key, length: byteLength)

        let bytesPerChar = byteLength / length
        var keyDataIterator = keyData.makeIterator()
        var offsets = [Int]()

        // Generates the offset
        for index in 0..<length {
            var data: String = ""
            var counter = 0

            // Add up bytevalues to value
            repeat {
                guard let byte = keyDataIterator.next() else {
                    throw PasswordGenerationError.keyGeneration
                }
                data += String(byte, radix: 2).pad(toSize: 8)
                counter += 1
            } while counter < bytesPerChar

            // Calculate offset and add to array
            offsets.append((characterIndices[index] - Int(data, radix: 2)!) % (chars.count + 1)) // TODO: check if this can be safely done
        }

        return offsets
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

        // #bits N = L x ceil(log2(C)) + (128 + L - (128 % L), where L is password length and C is character set cardinality, see Horsch(2017), p90
        let bitLength = length * Int(ceil(log2(Double(chars.count)))) + (128 + length - (128 % length))
        let byteLength = roundUp(n: bitLength, m: (length * 8)) / 8 // Round to nearest multiple of L * 8, so we can use whole bytes
        let keyData = try Crypto.sharedInstance.deterministicRandomBytes(seed: key, length: byteLength)

        // Zero-offsets if no offset is given
        // This will probably produce errors when password rejection is implemented because reference to offset is passed, not value
        let modulus = offset == nil ? chars.count : chars.count + 1
        let offset = offset ?? Array<Int>(repeatElement(0, count: length))
        let bytesPerChar = byteLength / length
        var keyDataIterator = keyData.makeIterator()
        var password = ""

        // Generates the password
        for index in 0..<length {
            var data: String = ""
            var counter = 0

            // Add up bytevalues to value
            repeat {
                guard let byte = keyDataIterator.next() else {
                    throw PasswordGenerationError.keyGeneration
                }
                data += String(byte, radix: 2).pad(toSize: 8)
                counter += 1
            } while counter < bytesPerChar

            // Choose character from value, taking offset into account
            let characterValue = (Int(data, radix: 2)! + offset[index]) % modulus // TODO: check if this can be safely done
            if characterValue != chars.count {
                password += String(chars[characterValue])
            }
        }

        return password
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
