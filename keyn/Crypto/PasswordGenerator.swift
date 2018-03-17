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


    func generatePassword(username: String, passwordIndex: Int, siteID: String, ppd: PPD?, offset: [Int]?) throws -> String {
        let (length, chars) = parse(ppd: ppd)

        let minLength = ppd?.properties?.minLength ?? 8
        guard length >= minLength else {
            throw PasswordGenerationError.tooShort
        }

        var password = ""
        repeat {
            password = try generatePasswordCandidate(username: username, passwordIndex: passwordIndex, siteID: siteID, length: length, chars: chars, offset: offset)
        } while !validate(password: password, for: ppd)

        return password
    }

    func calculatePasswordOffset(username: String, passwordIndex: Int, siteID: String, ppd: PPD?, password: String) throws -> [Int] {

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

    func validate(password: String, for ppd: PPD?) -> Bool {
        // TODO: Implement rejection sampling.

        if let maxConsecutive = ppd?.properties?.maxConsecutive {
            let passwordConsecutive = 1 // TODO: implement method to count consecutive characters
            guard passwordConsecutive <= maxConsecutive else {
                return false
            }
        }

        if let characterSetSettings = ppd?.properties?.characterSettings?.characterSetSettings {
            for characterSet in characterSetSettings {
                // TODO: Implement characterSet rules
//                characterSet.maxOccurs
//                guard passwordConsecutive <= maxConsecutive else {
//                    return false
//                }
            }
        }

        if let positionRestrictions = ppd?.properties?.characterSettings?.positionRestrictions {
            for positionRestriction in positionRestrictions {
                // TODO: Implement positionRestriction Rules
            }
        }

        if let requirementGroups = ppd?.properties?.characterSettings?.requirementGroups {
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
        }

        // assume
        return true
    }


    private func roundUp(n: Int, m: Int) -> Int {
        return n >= 0 ? ((n + m - 1) / m) * m : (n / m) * m
    }


    private func generateKey(username: String, passwordIndex: Int, siteID: String) throws -> Data {
        guard let usernameData = username.data(using: .utf8),
            let siteData = siteID.data(using: .utf8) else {
                throw PasswordGenerationError.dataConversion
        }

        // TODO: If siteID is Int, use that as index. siteData is then not necessary anymore.
        let siteKey = try Crypto.sharedInstance.deriveKey(keyData: Seed.getPasswordKey(), context: siteData)
        let key = try Crypto.sharedInstance.deriveKey(keyData: siteKey, context: usernameData, passwordIndex: passwordIndex)

        return key
    }
    
}
