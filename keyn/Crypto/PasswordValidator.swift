//
//  PasswordValidator.swift
//  keyn
//
//  Created by bas on 21/03/2018.
//  Copyright © 2018 keyn. All rights reserved.
//

import Foundation
import JustLog

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
                if let characters = characterSet.characters {
                    self.characters += String(characters.sorted())
                }
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
        return password.count <= maxLength
    }

    func validateMinLength(password: String) -> Bool {
        let minLength = ppd?.properties?.minLength ?? PasswordValidator.MIN_PASSWORD_LENGTH_BOUND
        return password.count >= minLength
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
    
    func validateBreaches(password: String, completionHandler: @escaping (Int) -> Void) {
        let hash = password.sha1().uppercased()
        let index = hash.index(hash.startIndex, offsetBy: 5)
        let prefix = hash.prefix(upTo: index).uppercased()
        let url = URL(string: "https://api.pwnedpasswords.com/range/\(prefix)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                Logger.shared.warning("Error querying HIBP", error: error! as NSError)
                completionHandler(0)
                return
            }
            
            if let httpStatus = response as? HTTPURLResponse {
                if httpStatus.statusCode == 200, let responseString = String(data: data, encoding: .utf8) {
                    var breachCount: Int? = nil
                    for line in responseString.lines {
                        let result = line.split(separator: ":")
                        if hash == prefix + result[0] {
                            breachCount = Int(result[1])
                        }
                    }
                    completionHandler(breachCount ?? 0)
                } else if let error = error {
                    Logger.shared.warning("Error querying HIBP", error: error as NSError, userInfo: [
                        "statusCode": httpStatus.statusCode
                        ])
                }
            }
        }
        task.resume()
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
                Logger.shared.debug("CharacterSet wasn't found in dictionary. Inconsistency in PPD?")
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
                     Logger.shared.debug("CharacterSet wasn't found in dictionary. Inconsistency in PPD?")
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
            }
        }
        return occurences
    }

    private func countCharacterOccurences(password: String, characterSet: String) -> Int {
        var occurences = 0
        for character in password {
            if characterSet.contains(character) { occurences += 1 }
        }
        return occurences
    }

}
