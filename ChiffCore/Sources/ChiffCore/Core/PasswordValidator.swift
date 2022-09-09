//
//  PasswordValidator.swift
//  ChiffCore
//
//  Copyright: see LICENSE.md
//

import Foundation

/// Validates a password against a set of rules, as specified in a `PPD`.
class PasswordValidator {

    static let fallbackPasswordLength = 22
    static let minPasswordLength = 8
    static let maxPasswordLength = 50
    static let optimalCharacterSet = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0987654321"
    static let allCharacterSet = " !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~" // All printable ASCII characters
    let ppd: PPD?
    var characterSetDictionary = [String: String]()
    var characters = ""

    init(ppd: PPD?) {
        self.ppd = ppd

        if let characterSets = ppd?.characterSets {
            if ppd?.version == .v1_0 {
                for characterSet in characterSets {
                    if let characters = characterSet.characters {
                        self.characters += String(characters.sorted())
                        characterSetDictionary[characterSet.name] = characterSet.characters
                    }
                }
            } else {
                var chars = Set<Character>()
                for characterSet in characterSets {
                    var setChars = Set<Character>()
                    if let baseCharacters = characterSet.base?.characters {
                        setChars.formUnion(baseCharacters.sorted())
                    }
                    if let additionalCharacters = characterSet.characters {
                        setChars.formUnion(additionalCharacters.sorted())
                    }
                    characterSetDictionary[characterSet.name] = String(setChars.sorted())
                    chars.formUnion(setChars)
                }
                self.characters = String(chars.sorted())
            }
        } else {
            characters += PasswordValidator.optimalCharacterSet
        }
    }

    /// Validate a password against all rules, as specified in the `PPD`.
    /// - Parameter password: The password that should be checked.
    /// - Throws: May throw if there are inconsistencies in the `PPD`.
    /// - Returns: True if valid, false otherwise
    func validate(password: String) throws -> Bool {
        guard validateMaxLength(password: password) else { return false }

        guard validateMinLength(password: password) else { return false }

        guard validateCharacters(password: password) else { return false }

        guard validateConsecutiveCharacters(password: password) else { return false }

        guard validateConsecutiveOrderedCharacters(password: password) else { return false }

        guard try validateCharacterSet(password: password) else { return false }

        guard try validatePositionRestrictions(password: password) else { return false }

        guard try validateRequirementGroups(password: password) else { return false }

        // All tests passed, password is valid.
        return true
    }

    /// Checks if password is less than or equal to maximum length. Relevant for custom passwords.
    /// - Parameter password: The password that should be checked.
    func validateMaxLength(password: String) -> Bool {
        let maxLength = ppd?.properties?.maxLength ?? PasswordValidator.maxPasswordLength
        return password.count <= maxLength
    }

    /// Checks if password is less than or equal to minimum length. Relevant for custom passwords.
    /// - Parameter password: The password that should be checked.
    func validateMinLength(password: String) -> Bool {
        let minLength = ppd?.properties?.minLength ?? PasswordValidator.minPasswordLength
        return password.count >= minLength
    }

    /// Checks if password doesn't contain forbidden characters.
    /// - Parameters:
    ///   - password: The password that should be checked.
    ///   - characters: Optionally, the characters can be overridden. Uses the objects characters otherwise.
    func validateCharacters(password: String, characters: String? = nil) -> Bool {
        let chars = characters ?? self.characters
        for char in password {
            guard chars.contains(char) else {
                return false
            }
        }
        return true
    }

    /// Max consecutive characters. This tests if *n* characters are the same.
    /// - Parameter password: The password that should be checked.
    func validateConsecutiveCharacters(password: String) -> Bool {
        if let maxConsecutive = ppd?.properties?.maxConsecutive, maxConsecutive > 0 {
            guard checkConsecutiveCharacters(password: password, characters: characters, maxConsecutive: maxConsecutive) else {
                return false
            }
        }
        return true
    }

    /// Max consecutive characters. This tests if *n* characters are in an ordered sequence.
    /// - Parameter password: The password that should be checked.
    func validateConsecutiveOrderedCharacters(password: String) -> Bool {
        if let maxConsecutive = ppd?.properties?.maxConsecutive, maxConsecutive > 0 {
            guard checkConsecutiveCharactersOrder(password: password, characters: characters, maxConsecutive: maxConsecutive) else {
                return false
            }
        }
        return true
    }

    /// Validates the characterSetSettings.
    /// These may for example specifiy that the password should contains at least *n* characters of set *LowerLetters*.
    /// - Parameter password: The password that should be checked.
    func validateCharacterSet(password: String) throws -> Bool {
        if let characterSetSettings = ppd?.properties?.characterSettings?.characterSetSettings {
            guard try checkCharacterSetSettings(password: password, characterSetSettings: characterSetSettings) else {
                return false
            }
        }
        return true
    }

    /// Validates the position restrictions.
    /// These may for example specify that the password should start with an *UpperCase* character.
    /// - Parameter password: The password that should be checked.
    func validatePositionRestrictions(password: String) throws -> Bool {
        if let positionRestrictions = ppd?.properties?.characterSettings?.positionRestrictions {
            guard try checkPositionRestrictions(password: password, positionRestrictions: positionRestrictions) else {
                return false
            }
        }
        return true
    }

    /// Validates the requirement groups.
    /// These may specify combinations of characterSetSettings and positionRestrictions, where at least *n* of these rules should be valid.
    /// - Parameter password: The password that should be checked.
    func validateRequirementGroups(password: String) throws -> Bool {
        if let requirementGroups = ppd?.properties?.characterSettings?.requirementGroups {
            guard try checkRequirementGroups(password: password, requirementGroups: requirementGroups) else {
                return false
            }
        }
        return true
    }

    // MARK: - Private functions

    private func checkConsecutiveCharacters(password: String, characters: String, maxConsecutive: Int) -> Bool {
        let escapedCharacters = NSRegularExpression.escapedPattern(for: characters).replacingOccurrences(of: "\\]", with: "\\\\]", options: .regularExpression)
        let pattern = "([\(escapedCharacters)])\\1{\(maxConsecutive),}"

        return password.range(of: pattern, options: .regularExpression) == nil
    }

    private func checkConsecutiveCharactersOrder(password: String, characters: String, maxConsecutive: Int) -> Bool {
        var lastValue = 256
        var longestSequence = 0
        var counter = 1

        for value in password.utf8 {
            // We use OPTIMAL_CHARACTER_SET because the order only makes sense for letters and numbers
            if value == lastValue + 1 && PasswordValidator.optimalCharacterSet.utf8.contains(value) {
                counter += 1
            } else {
                counter = 1
            }

            lastValue = Int(value)
            if counter > longestSequence {
                longestSequence = counter
            }
        }

        return longestSequence <= maxConsecutive
    }

    private func checkCharacterSetSettings(password: String, characterSetSettings: [PPDCharacterSetSettings]) throws -> Bool {
        for characterSetSetting in characterSetSettings {
            if let characterSet = characterSetDictionary[characterSetSetting.name] {
                let occurences = countCharacterOccurences(password: password, characterSet: characterSet)
                if let minOccurs = characterSetSetting.minOccurs, occurences < minOccurs {
                    return false
                }
                if let maxOccurs = characterSetSetting.maxOccurs, occurences > maxOccurs {
                    return false
                }
            } else {
                throw PasswordGenerationError.ppdInconsistency
            }
        }
        return true
    }

    private func checkPositionRestrictions(password: String, positionRestrictions: [PPDPositionRestriction]) throws -> Bool {
        for positionRestriction in positionRestrictions {
            if let characterSet = characterSetDictionary[positionRestriction.characterSet] {
                let occurences = checkPositions(password: password, positions: positionRestriction.positions, characterSet: characterSet)
                guard occurences >= positionRestriction.minOccurs else { return false }
                if let maxOccurs = positionRestriction.maxOccurs, occurences > maxOccurs {
                    return false
                }
            } else {
                throw PasswordGenerationError.ppdInconsistency
            }
        }
        return true
    }

    private func checkRequirementGroups(password: String, requirementGroups: [PPDRequirementGroup]) throws -> Bool {
        for requirementGroup in requirementGroups {
            //requirementGroup.minRules = minimum amount of rules password
            var validRules = 0
            for requirementRule in requirementGroup.requirementRules {
                var occurences = 0
                if let characterSet = characterSetDictionary[requirementRule.characterSet] {
                    if let positions = requirementRule.positions {
                        occurences += checkPositions(password: password, positions: positions, characterSet: characterSet)
                    } else {
                        occurences += countCharacterOccurences(password: password, characterSet: characterSet)
                    }

                    if let maxOccurs = requirementRule.maxOccurs {
                        if occurences >= requirementRule.minOccurs && occurences <= maxOccurs { validRules += 1 }
                    } else {
                        if occurences >= requirementRule.minOccurs { validRules += 1 }
                    }
                } else {
                     throw PasswordGenerationError.ppdInconsistency
                }
            }
            guard validRules >= requirementGroup.minRules else {
                return false
            }
        }
        return true
    }

    private func checkPositions(password: String, positions: String, characterSet: String) -> Int {
        var occurences = 0
        for position in positions.split(separator: ",") {
            if let position = Int(position) {
                let index = password.index(position < 0 ? password.endIndex : password.startIndex, offsetBy: position)
                if characterSet.contains(password[index]) {
                    occurences += 1
                }
            }
        }
        return occurences
    }

    private func countCharacterOccurences(password: String, characterSet: String) -> Int {
        return password.reduce(0, { characterSet.contains($1) ? $0 + 1 : $0 })
    }

}
