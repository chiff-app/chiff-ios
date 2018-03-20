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
}


class PasswordGenerator {

    static let sharedInstance = PasswordGenerator()
    private let FALLBACK_PASSWORD_LENGTH = 22
    private let MAX_PASSWORD_LENGTH_BOUND = 50
    private let OPTIMAL_CHARACTER_SET = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0987654321"
    private init() {} //This prevents others from using the default '()' initializer for this singleton class.


    func generatePassword(username: String, passwordIndex: Int, siteID: Int, ppd: PPD?, offset: [Int]?) throws -> String {
        let (length, chars) = parse(ppd: ppd)

        let minLength = ppd?.properties?.minLength ?? 8
        guard length >= minLength else {
            throw PasswordGenerationError.tooShort
        }

        var password = ""
        repeat {
            password = try generatePasswordCandidate(username: username, passwordIndex: passwordIndex, siteID: siteID, length: length, chars: chars, offset: offset)
        } while ppd != nil ? !validate(password: password, for: ppd!) : false

        return password
    }

    func calculatePasswordOffset(username: String, passwordIndex: Int, siteID: Int, ppd: PPD?, password: String) throws -> [Int] {

        // TODO: We should check first if password complies with PPD, otherwise throw error. Or use different function so custom passwords can be verified while typing

        let (length, chars) = parse(ppd: ppd)

        let minLength = ppd?.properties?.minLength ?? 8
        guard length >= minLength else {
            throw PasswordGenerationError.tooShort
        }

        var characterIndices = [Int](repeatElement(chars.count, count: length))
        var index = 0

        // This is part of validating password: checking for disallowed characters
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

    private func generatePasswordCandidate(username: String, passwordIndex: Int, siteID: Int, length: Int, chars: [Character], offset: [Int]?) throws -> String {
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

    private func parse(ppd: PPD?) -> (Int, [Character]) {
        var length = FALLBACK_PASSWORD_LENGTH
        var chars = [Character]()

        if let characterSets = ppd?.characterSets {
            for characterSet in characterSets {
                if let characters = characterSet.characters {
                    chars.append(contentsOf: [Character](characters))
                }
            }
        } else {
            chars.append(contentsOf: [Character](OPTIMAL_CHARACTER_SET)) // Optimal character set
        }

        if let maxLength = ppd?.properties?.maxLength {
            length = maxLength < MAX_PASSWORD_LENGTH_BOUND ? min(maxLength, MAX_PASSWORD_LENGTH_BOUND) : Int(ceil(128/log2(Double(chars.count))))
        }

        return (length, chars)
    }

    func checkConsecutiveCharacters(password: String, characters: String, maxConsecutive: Int) -> Bool {
        let escapedCharacters = NSRegularExpression.escapedPattern(for: characters).replacingOccurrences(of: "\\]", with: "\\\\]", options: .regularExpression)
        let pattern = "([\(escapedCharacters)])\\1{\(maxConsecutive),}"
        return password.range(of: pattern, options: .regularExpression) == nil
    }

    func checkConsecutiveCharactersOrder(password: String, characters: String, maxConsecutive: Int) -> Bool {
        var lastValue = 256
        var longestSequence = 0
        var counter = 1
        for value in password.utf8 {
            if value == lastValue + 1 && OPTIMAL_CHARACTER_SET.utf8.contains(value) {
                counter += 1
            } else { counter = 1 }
            lastValue = Int(value)
            if counter > longestSequence { longestSequence = counter }
        }
        return longestSequence <= maxConsecutive
    }

    func checkCharacterSetSettings(password: String, characterSetSettings: [PPDCharacterSetSettings], characterSetDictionary: [String:String]) -> Bool {
        for characterSetSetting in characterSetSettings {
            if let characterSet = characterSetDictionary[characterSetSetting.name] {
                let escapedCharacters = NSRegularExpression.escapedPattern(for: characterSet).replacingOccurrences(of: "\\]", with: "\\\\]", options: .regularExpression)
                do {
                    let regex = try NSRegularExpression(pattern: "[\(escapedCharacters)]")
                    let range = NSMakeRange(0, password.count)
                    let numberOfMatches = regex.numberOfMatches(in: password, range: range)
                    if let minOccurs = characterSetSetting.minOccurs {
                        guard numberOfMatches >= minOccurs else { return false }
                    }
                    if let maxOccurs = characterSetSetting.maxOccurs {
                        guard numberOfMatches <= maxOccurs else { return false }
                    }
                } catch {
                    print("There was an error creating the NSRegularExpression: \(error)")
                }
            }
        }
        return true
    }

    func checkPositionRestrictions(password: String, positionRestrictions: [PPDPositionRestriction], characterSetDictionary: [String:String]) -> Bool {
        for positionRestriction in positionRestrictions {
            for position in positionRestriction.positions.split(separator: ",") {
                if let position = Int(position) {
                    let index = password.index(position < 0 ? password.endIndex : password.startIndex, offsetBy: position)
                    if let characterSet = characterSetDictionary[positionRestriction.characterSet] {
                        if !characterSet.contains(password[index]) { return false }
                    }
                } else if let position = Double(position) {
                    print("TODO: Fix relative positions: \(position)")
                    // TODO: minOccurs and maxOccurs are not yet taken into account.
                }
            }
        }
        return true
    }

    func checkRequirementGroups(password: String, requirementGroups: [PPDRequirementGroup]) -> Bool {
        for requirementGroup in requirementGroups {
            //requirementGroup.minRules = minimum amount of rules password
            var validRules = 0
            for requirementRule in requirementGroup.requirementRules {
                if requirementRule.maxOccurs! > 0 {
                    validRules += 1
                }
            }
            if validRules < requirementGroup.minRules {
                return false
            }
        }
        return false
    }


    func validate(password: String, for ppd: PPD) -> Bool {
        // Checks if password is less than or equal to maximum length. Relevant for custom passwords
        if let maxLength = ppd.properties?.maxLength {
            guard password.count <= maxLength else {
                return false
            }
        }

        // Checks if password is less than or equal to minimum length. Relevant for custom passwords
        if let minLength = ppd.properties?.minLength {
            guard password.count >= minLength else {
                return false
            }
        }

        // Joins all allowed characters into one string, which is used by consecutiveCharacters()
        var characters = ""
        var characterSetDictionary = [String:String]()
        if let characterSets = ppd.characterSets {
            characterSets.forEach({ (characterSet) in
                characters += characterSet.characters ?? ""
                characterSetDictionary[characterSet.name] = characterSet.characters
            })
        } else { characters += OPTIMAL_CHARACTER_SET } // PPD doesn't contain characterSets. That shouldn't be right. TODO: Check with XSD if characterSet can be null..

        // Checks if password doesn't contain unallowed characters
        for char in password {
            guard characters.contains(char) else {
                return false
            }
        }
        
        // Max consecutive characters. This tests if n characters are the same or are an ordered sequence. TODO
        if let maxConsecutive = ppd.properties?.maxConsecutive, maxConsecutive > 0 {
            guard checkConsecutiveCharacters(password: password, characters: characters, maxConsecutive: maxConsecutive) else {
                return false
            }
            guard checkConsecutiveCharactersOrder(password: password, characters: characters, maxConsecutive: maxConsecutive) else {
                return false
            }
        }

        // CharacterSet restrictions
        if let characterSetSettings = ppd.properties?.characterSettings?.characterSetSettings {
            guard checkCharacterSetSettings(password: password, characterSetSettings: characterSetSettings, characterSetDictionary: characterSetDictionary) else {
                return false
            }
        }

        // Position restrictions
        if let positionRestrictions = ppd.properties?.characterSettings?.positionRestrictions {
            guard checkPositionRestrictions(password: password, positionRestrictions: positionRestrictions, characterSetDictionary: characterSetDictionary) else {
                return false
            }
        }

        // Requirement groups
        if let requirementGroups = ppd.properties?.characterSettings?.requirementGroups {
            guard checkRequirementGroups(password: password, requirementGroups: requirementGroups) else {
                return false
            }
        }

        // All tests passed, password is valid.
        return true
    }


    private func roundUp(n: Int, m: Int) -> Int {
        return n >= 0 ? ((n + m - 1) / m) * m : (n / m) * m
    }


    private func generateKey(username: String, passwordIndex: Int, siteID: Int) throws -> Data {
        guard let usernameData = username.data(using: .utf8),
            let siteData = "sitedata".data(using: .utf8) else {
                throw PasswordGenerationError.dataConversion
        }

        // TODO: SiteData is now a constant. Should we use a variable (besides the siteID as index?)
        let siteKey = try Crypto.sharedInstance.deriveKey(keyData: Seed.getPasswordKey(), context: siteData, index: siteID)
        let key = try Crypto.sharedInstance.deriveKey(keyData: siteKey, context: usernameData, index: passwordIndex)

        return key
    }
    
}
