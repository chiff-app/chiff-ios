//
//  PasswordValidator.swift
//  keyn
//
//  Created by bas on 21/03/2018.
//  Copyright © 2018 keyn. All rights reserved.
//

import Foundation

class PasswordValidator {
    static let FALLBACK_PASSWORD_LENGTH = 22
    static let MIN_PASSWORD_LENGTH_BOUND = 8 // TODO: What is sensible value for this?
    static let MAX_PASSWORD_LENGTH_BOUND = 50
    static let OPTIMAL_CHARACTER_SET = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0987654321"
    let ppd: PPD?
    var characterSetDictionary = [String:String]()
    var characters = ""


    init(ppd: PPD?) {
        self.ppd = ppd
        if let characterSets = ppd?.characterSets {
            for characterSet in characterSets {
                characters += characterSet.characters ?? ""
                characterSetDictionary[characterSet.name] = characterSet.characters
            }
        } else { characters += PasswordValidator.OPTIMAL_CHARACTER_SET } // PPD doesn't contain characterSets. That shouldn't be right. TODO: Check with XSD if characterSet can be null..
    }

    func validate(password: String) -> Bool {
        // Checks if password is less than or equal to maximum length. Relevant for custom passwords
        guard validateMaxLength(password: password) else { return false }

        // Checks if password is less than or equal to minimum length. Relevant for custom passwords
        guard validateMinLength(password: password) else { return false }

        // Checks if password doesn't contain unallowed characters
        guard validateCharacters(password: password) else { return false }

        // Max consecutive characters. This tests if n characters are the same.
        guard validateConsecutiveCharacters(password: password) else { return false }

        // Max consecutive characters. This tests if n characters are an ordered sequence.
        guard validateConsecutiveOrderedCharacters(password: password) else { return false }

        // CharacterSet restrictions
        guard validateCharacterSet(password: password) else { return false }

        // Position restrictions
        guard validatePositionRestrictions(password: password) else { return false }

        // Requirement groups
        guard validateRequirementGroups(password: password) else { return false }

        // All tests passed, password is valid.
        return true
    }

    func validateMaxLength(password: String) -> Bool {
        let maxLength = ppd?.properties?.maxLength ?? PasswordValidator.MAX_PASSWORD_LENGTH_BOUND
        guard password.count <= maxLength else {
            return false
        }
        return true
    }

    func validateMinLength(password: String) -> Bool {
        let minLength = ppd?.properties?.minLength ?? PasswordValidator.MIN_PASSWORD_LENGTH_BOUND
        guard password.count >= minLength else {
            return false
        }
        return true
    }

    // TODO: To what characterSet should we validate a custom password without a PPD? Now optimal characterSet (see init)
    func validateCharacters(password: String) -> Bool {
        for char in password {
            guard characters.contains(char) else {
                return false
            }
        }
        return true
    }

    func validateConsecutiveCharacters(password: String) -> Bool {
        if let maxConsecutive = ppd?.properties?.maxConsecutive, maxConsecutive > 0 {
            guard checkConsecutiveCharacters(password: password, characters: characters, maxConsecutive: maxConsecutive) else {
                return false
            }
        }
        return true
    }


    func validateConsecutiveOrderedCharacters(password: String) -> Bool {
        if let maxConsecutive = ppd?.properties?.maxConsecutive, maxConsecutive > 0 {
            guard checkConsecutiveCharactersOrder(password: password, characters: characters, maxConsecutive: maxConsecutive) else {
                return false
            }
        }
        return true
    }

    func validateCharacterSet(password: String) -> Bool {
        if let characterSetSettings = ppd?.properties?.characterSettings?.characterSetSettings {
            guard checkCharacterSetSettings(password: password, characterSetSettings: characterSetSettings) else {
                return false
            }
        }
        return true
    }

    func validatePositionRestrictions(password: String) -> Bool {
        if let positionRestrictions = ppd?.properties?.characterSettings?.positionRestrictions {
            guard checkPositionRestrictions(password: password, positionRestrictions: positionRestrictions) else {
                return false
            }
        }
        return true
    }

    func validateRequirementGroups(password: String) -> Bool {
        if let requirementGroups = ppd?.properties?.characterSettings?.requirementGroups {
            guard checkRequirementGroups(password: password, requirementGroups: requirementGroups) else {
                return false
            }
        }
        return true
    }

    // MARK: Private functions

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
            if value == lastValue + 1 && PasswordValidator.OPTIMAL_CHARACTER_SET.utf8.contains(value) {
                counter += 1
            } else { counter = 1 }
            lastValue = Int(value)
            if counter > longestSequence { longestSequence = counter }
        }
        return longestSequence <= maxConsecutive
    }

    private func checkCharacterSetSettings(password: String, characterSetSettings: [PPDCharacterSetSettings]) -> Bool {
        for characterSetSetting in characterSetSettings {
            if let characterSet = characterSetDictionary[characterSetSetting.name] {
                let occurences = countCharacterOccurences(password: password, characterSet: characterSet)
                if let minOccurs = characterSetSetting.minOccurs {
                    guard occurences >= minOccurs else { return false }
                }
                if let maxOccurs = characterSetSetting.maxOccurs {
                    guard occurences <= maxOccurs else { return false }
                }
            }
        }
        return true
    }

    private func checkPositionRestrictions(password: String, positionRestrictions: [PPDPositionRestriction]) -> Bool {
        for positionRestriction in positionRestrictions {
            if let characterSet = characterSetDictionary[positionRestriction.characterSet] {
                let occurences = checkPositions(password: password, positions: positionRestriction.positions, characterSet: characterSet)
                guard occurences >= positionRestriction.minOccurs else { return false }
                if let maxOccurs = positionRestriction.maxOccurs {
                    guard occurences <= maxOccurs else { return false }
                }
            } else {
                print("CharacterSet wasn't found in dictionary. Inconsistency in PPD?")
            }
        }
        return true
    }

    private func checkRequirementGroups(password: String, requirementGroups: [PPDRequirementGroup]) -> Bool {
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
                    print("CharacterSet wasn't found in dictionary. Inconsistency in PPD?")
                }
            }
            guard validRules >= requirementGroup.minRules else  {
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
                if characterSet.contains(password[index]) { occurences += 1 }
            } else if let position = Double(position) {
                let index = position * Double(password.count) - 0.5
                let upperIndex = Int(ceil(index))
                let lowerIndex = Int(floor(index))
                if upperIndex == lowerIndex {
                    let letter = password[password.index(password.startIndex, offsetBy: upperIndex)]
                    if characterSet.contains(letter) { occurences += 1 }
                } else {
                    let firstLetter = password[password.index(password.startIndex, offsetBy: upperIndex)]
                    let secondLetter = password[password.index(password.startIndex, offsetBy: lowerIndex)]
                    if characterSet.contains(firstLetter) && characterSet.contains(secondLetter) { occurences += 1 } // Should this be AND or OR? i.e. do the letter right and left of index need to be correct or just one?
                }
            }
        }
        return occurences
    }

    private func countCharacterOccurences(password: String, characterSet: String) -> Int {
        let escapedCharacters = NSRegularExpression.escapedPattern(for: characterSet).replacingOccurrences(of: "\\]", with: "\\\\]", options: .regularExpression)
        // TODO: Crash app for now
//        do {
            let regex = try! NSRegularExpression(pattern: "[\(escapedCharacters)]")
            let range = NSMakeRange(0, password.count)
            return regex.numberOfMatches(in: password, range: range)
//        } catch {
//            print("There was an error creating the NSRegularExpression: \(error)")        
//        }
    }

}
