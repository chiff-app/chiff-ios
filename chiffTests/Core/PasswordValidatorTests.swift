//
//  PasswordValidatorTests.swift
//  chiffTests
//
//  Copyright: see LICENSE.md
//

import XCTest

@testable import chiff

/*
 * We test the public validate() function for now. In the future
 * we might decide to also test the individual methods but perhaps
 * they will all become private. See Trello issue 187.
 */
class PasswordValidatorTests: XCTestCase {

    func testPPDWithoutCharacterSet() {
        let ppd = PPD(characterSets: nil, properties: nil, service: nil, version: .v1_1, timestamp: 0, url: "https://test.com", redirect: nil, name: "Test")
        let validator = PasswordValidator(ppd: ppd)
        let password = "Ver8aspdisd8nad8*(&sa"

        XCTAssertEqual(try validator.validate(password: password), false)
    }

    func testValidateReturnsFalseWhenMaxLengthExceeded() {
        let ppdv1_1 = TestHelper.samplePPDV1_1(minLength: 8, maxLength: 32)
        let ppdv1 = TestHelper.samplePPD(minLength: 8, maxLength: 32)
        let validatorV1_1 = PasswordValidator(ppd: ppdv1_1)
        let validatorV1 = PasswordValidator(ppd: ppdv1)
        let password = "Ver8aspdisd8nad8*(&sa8d97mjaVer8a" // 33 Characters

        XCTAssertEqual(try validatorV1.validate(password: password), false)
        XCTAssertEqual(try validatorV1_1.validate(password: password), false)
    }

    func testValidateReturnsFalseWhenMinLengthUnderceeded() { // is this even a word?
        let ppdv1_1 = TestHelper.samplePPDV1_1(minLength: 8, maxLength: 32)
        let ppdv1 = TestHelper.samplePPD(minLength: 8, maxLength: 32)
        let validatorV1_1 = PasswordValidator(ppd: ppdv1_1)
        let validatorV1 = PasswordValidator(ppd: ppdv1)
        let password = "Sh0rt*r" // 7 characters

        XCTAssertEqual(try validatorV1_1.validate(password: password), false)
        XCTAssertEqual(try validatorV1.validate(password: password), false)
    }

    func testValidateReturnsFalseWhenMaxLengthExceededUsingFallback() {
        let ppdv1_1 = TestHelper.samplePPDV1_1(minLength: 8, maxLength: nil)
        let ppdv1 = TestHelper.samplePPD(minLength: 8, maxLength: nil)
        let validatorV1_1 = PasswordValidator(ppd: ppdv1_1)
        let validatorV1 = PasswordValidator(ppd: ppdv1)
        let password = String(repeating: "a", count: PasswordValidator.maxPasswordLength + 1)

        XCTAssertEqual(try validatorV1_1.validate(password: password), false)
        XCTAssertEqual(try validatorV1.validate(password: password), false)
    }

    func testValidateReturnsFalseWhenMinLengthUnderceededUsingFallback() {
        let ppdv1_1 = TestHelper.samplePPDV1_1(minLength: nil, maxLength: 32)
        let ppdv1 = TestHelper.samplePPD(minLength: nil, maxLength: 32)
        let validatorV1_1 = PasswordValidator(ppd: ppdv1_1)
        let validatorV1 = PasswordValidator(ppd: ppdv1)
        let password = String(repeating: "a", count: PasswordValidator.minPasswordLength - 1)

        XCTAssertEqual(try validatorV1_1.validate(password: password), false)
        XCTAssertEqual(try validatorV1.validate(password: password), false)
    }

    func testValidateReturnsFalseForUnallowedCharacters() {
        let ppdv1_1 = TestHelper.samplePPDV1_1(minLength: 8, maxLength: 32)
        let ppdv1 = TestHelper.samplePPD(minLength: 8, maxLength: 32)
        let validatorV1_1 = PasswordValidator(ppd: ppdv1_1)
        let validatorV1 = PasswordValidator(ppd: ppdv1)

        XCTAssertEqual(try validatorV1.validate(password: "Ver8aspdi€sd8na"), false)
        XCTAssertEqual(try validatorV1_1.validate(password: "Ver8aspdi€sd8na"), false)
    }

    func testValidateReturnsFalseForTooManyConsecutiveCharacters() {
        let ppdv1_1 = TestHelper.samplePPDV1_1(minLength: 8, maxLength: 32, maxConsecutive: 3)
        let ppdv1 = TestHelper.samplePPD(minLength: 8, maxLength: 32, maxConsecutive: 3)
        let validatorV1_1 = PasswordValidator(ppd: ppdv1_1)
        let validatorV1 = PasswordValidator(ppd: ppdv1)
        let password = "sod8na9p8d7snaaaa" // 4 consecutive characters

        XCTAssertEqual(try validatorV1_1.validate(password: password), false)
        XCTAssertEqual(try validatorV1.validate(password: password), false)
    }

    func testValidateReturnsFalseForTooManyOrderedConsecutiveCharacters() {
        let ppdv1_1 = TestHelper.samplePPDV1_1(minLength: 8, maxLength: 32, maxConsecutive: 3)
        let ppdv1 = TestHelper.samplePPD(minLength: 8, maxLength: 32, maxConsecutive: 3)
        let validatorV1_1 = PasswordValidator(ppd: ppdv1_1)
        let validatorV1 = PasswordValidator(ppd: ppdv1)
        let password = "sod8na9p8d7snabcd" // 4 ordered consecutive characters abcd

        XCTAssertEqual(try validatorV1_1.validate(password: password), false)
        XCTAssertEqual(try validatorV1.validate(password: password), false)
    }

    func testValidateReturnsTrueForOrderedConsecutiveCharacters() {
        let ppdv1_1 = TestHelper.samplePPDV1_1(minLength: 8, maxLength: 32, maxConsecutive: 3)
        let ppdv1 = TestHelper.samplePPD(minLength: 8, maxLength: 32, maxConsecutive: 3)
        let validatorV1_1 = PasswordValidator(ppd: ppdv1_1)
        let validatorV1 = PasswordValidator(ppd: ppdv1)
        let password = "sod8na9p8d7snabc" // 3 ordered consecutive characters abcd

        XCTAssertEqual(try validatorV1_1.validate(password: password), true)
        XCTAssertEqual(try validatorV1.validate(password: password), true)
    }

    // For readability the character sets are defined in Testhelper.examplePPPD().
    func testValidateReturnsFalseWhenCharacterSetMinOccursNotMet() {
        var characterSetSettings = [PPDCharacterSetSettings]()
        characterSetSettings.append(PPDCharacterSetSettings(minOccurs: 1, maxOccurs: nil, name: "UpperLetters"))

        let ppdv1 = TestHelper.samplePPD(minLength: 8, maxLength: 32, maxConsecutive: 0, characterSetSettings: characterSetSettings)
        let ppdv1_1 = TestHelper.samplePPDV1_1(minLength: 8, maxLength: 32, maxConsecutive: 0, characterSetSettings: characterSetSettings)
        let validatorV1_1 = PasswordValidator(ppd: ppdv1)
        let validatorV1 = PasswordValidator(ppd: ppdv1_1)

        XCTAssertEqual(try validatorV1_1.validate(password: "onlylowerletters"), false)
        XCTAssertEqual(try validatorV1.validate(password: "onlylowerletters"), false)
    }

    func testValidateReturnsFalseWhenCharacterSetMaxOccursExceeded() {
        var characterSetSettings = [PPDCharacterSetSettings]()
        characterSetSettings.append(PPDCharacterSetSettings(minOccurs: nil, maxOccurs: 4, name: "UpperLetters"))

        let ppdv1 = TestHelper.samplePPD(minLength: 8, maxLength: 32, maxConsecutive: 0, characterSetSettings: characterSetSettings)
        let ppdv1_1 = TestHelper.samplePPDV1_1(minLength: 8, maxLength: 32, maxConsecutive: 0, characterSetSettings: characterSetSettings)
        let validatorV1_1 = PasswordValidator(ppd: ppdv1)
        let validatorV1 = PasswordValidator(ppd: ppdv1_1)

        XCTAssertEqual(try validatorV1_1.validate(password: "toomanyUPPER"), false)
        XCTAssertEqual(try validatorV1.validate(password: "toomanyUPPER"), false)
    }

    func testValidateReturnsFalseIfPositionRestrictionNotMet() {
        var positionRestrictions = [PPDPositionRestriction]()
        // Password should start with a captial
        positionRestrictions.append(PPDPositionRestriction(positions: "0", minOccurs: 1, maxOccurs: nil, characterSet: "UpperLetters"))

        let ppdv1 = TestHelper.samplePPD(minLength: 8, maxLength: 32, maxConsecutive: nil, characterSetSettings: nil, positionRestrictions: positionRestrictions, requirementGroups: nil)
        let ppdv1_1 = TestHelper.samplePPDV1_1(minLength: 8, maxLength: 32, maxConsecutive: nil, characterSetSettings: nil, positionRestrictions: positionRestrictions, requirementGroups: nil)
        let validatorV1 = PasswordValidator(ppd: ppdv1)
        let validatorV1_1 = PasswordValidator(ppd: ppdv1_1)

        XCTAssertEqual(try validatorV1.validate(password: "asdpuhfjkad45"), false)
        XCTAssertEqual(try validatorV1_1.validate(password: "asdpuhfjkad45"), false)
    }

    func testValidateReturnsFalseIfMultiplePositionRestrictionNotMet() {
        var positionRestrictions = [PPDPositionRestriction]()
        // There should be no more than 2 specials combined on positions 1, 2, 3
        positionRestrictions.append(PPDPositionRestriction(positions: "0,1,2", minOccurs: 0, maxOccurs: 2, characterSet: "Specials"))

        let ppdv1 = TestHelper.samplePPD(minLength: 8, maxLength: 32, maxConsecutive: nil, characterSetSettings: nil, positionRestrictions: positionRestrictions, requirementGroups: nil)
        let ppdv1_1 = TestHelper.samplePPDV1_1(minLength: 8, maxLength: 32, maxConsecutive: nil, characterSetSettings: nil, positionRestrictions: positionRestrictions, requirementGroups: nil)
        let validatorV1 = PasswordValidator(ppd: ppdv1)
        let validatorV1_1 = PasswordValidator(ppd: ppdv1_1)

        XCTAssertEqual(try validatorV1.validate(password: "**d**********"), true)
        XCTAssertEqual(try validatorV1.validate(password: "***puhfjkad45"), false)
        XCTAssertEqual(try validatorV1_1.validate(password: "**d**********"), true)
        XCTAssertEqual(try validatorV1_1.validate(password: "***puhfjkad45"), false)
    }

    func testValidateShouldReturnFalseIfRequirementGroupWithPositionsIsNotMet() {
        var requirementGroups = [PPDRequirementGroup]()
        let rule1 = PPDRequirementRule(positions: "0", minOccurs: 1, maxOccurs: nil, characterSet: "UpperLetters")
        let rule2 = PPDRequirementRule(positions: "-1,-2", minOccurs: 2, maxOccurs: 2, characterSet: "Numbers")
        requirementGroups.append(PPDRequirementGroup(minRules: 2, requirementRules: [rule1, rule2]))

        let ppdv1 = TestHelper.samplePPD(minLength: 8, maxLength: 32, maxConsecutive: nil, characterSetSettings: nil, positionRestrictions: nil, requirementGroups: requirementGroups)
        let ppdv1_1 = TestHelper.samplePPDV1_1(minLength: 8, maxLength: 32, maxConsecutive: nil, characterSetSettings: nil, positionRestrictions: nil, requirementGroups: requirementGroups)
        let validatorV1_1 = PasswordValidator(ppd: ppdv1_1)
        let validatorV1 = PasswordValidator(ppd: ppdv1)

        XCTAssertEqual(try validatorV1.validate(password: "Password123"), true)  // follows both
        XCTAssertEqual(try validatorV1.validate(password: "Password"), false)    // follows rule1 not rule2
        XCTAssertEqual(try validatorV1.validate(password: "password123"), false) // follows rule2 not rule1
        XCTAssertEqual(try validatorV1_1.validate(password: "Password123"), true)  // follows both
        XCTAssertEqual(try validatorV1_1.validate(password: "Password"), false)    // follows rule1 not rule2
        XCTAssertEqual(try validatorV1_1.validate(password: "password123"), false) // follows rule2 not rule1
    }

    func testValidateShouldReturnFalseIfRequirementGroupIsNotMet() {
        var requirementGroups = [PPDRequirementGroup]()
        let rule1 = PPDRequirementRule(positions: nil, minOccurs: 1, maxOccurs: nil, characterSet: "UpperLetters")
        let rule2 = PPDRequirementRule(positions: nil, minOccurs: 1, maxOccurs: 2, characterSet: "Numbers")
        requirementGroups.append(PPDRequirementGroup(minRules: 2, requirementRules: [rule1, rule2]))

        let ppdv1 = TestHelper.samplePPD(minLength: 8, maxLength: 32, maxConsecutive: nil, characterSetSettings: nil, positionRestrictions: nil, requirementGroups: requirementGroups)
        let ppdv1_1 = TestHelper.samplePPDV1_1(minLength: 8, maxLength: 32, maxConsecutive: nil, characterSetSettings: nil, positionRestrictions: nil, requirementGroups: requirementGroups)
        let validatorV1_1 = PasswordValidator(ppd: ppdv1_1)
        let validatorV1 = PasswordValidator(ppd: ppdv1)

        XCTAssertEqual(try validatorV1.validate(password: "Password12"), true)  // follows both
        XCTAssertEqual(try validatorV1.validate(password: "Password"), false)    // follows rule1 not rule2
        XCTAssertEqual(try validatorV1.validate(password: "Password123"), false) // follows rule1 not rule2
        XCTAssertEqual(try validatorV1.validate(password: "password12"), false) // follows rule2 not rule1
        XCTAssertEqual(try validatorV1_1.validate(password: "Password12"), true)  // follows both
        XCTAssertEqual(try validatorV1_1.validate(password: "Password"), false)    // follows rule1 not rule2
        XCTAssertEqual(try validatorV1_1.validate(password: "Password123"), false) // follows rule1 not rule2
        XCTAssertEqual(try validatorV1_1.validate(password: "password12"), false) // follows rule2 not rule1
    }

    func testInconsistentCharacterSetSetting() {
        var characterSets = [PPDCharacterSet]()
        characterSets.append(PPDCharacterSet(base: .lowerLetters, characters: nil, name: "NameWithTypo"))
        characterSets.append(PPDCharacterSet(base: .upperLetters, characters: "ABCDEFGHIJKLMNOPQRSTUVWXYZ", name: "UpperLetters"))
        characterSets.append(PPDCharacterSet(base: .numbers, characters: nil, name: "Numbers"))
        characterSets.append(PPDCharacterSet(base: .specials, characters: " ", name: "Specials"))

        let characterSetSettings = [PPDCharacterSetSettings(minOccurs: nil, maxOccurs: 4, name: "LowerLetters")] // Not present

        let ppdCharacterSettings = PPDCharacterSettings(characterSetSettings: characterSetSettings, requirementGroups: nil, positionRestrictions: nil)
        let properties = PPDProperties(characterSettings: ppdCharacterSettings, maxConsecutive: nil, minLength: nil, maxLength: nil)

        let ppd = PPD(characterSets: characterSets, properties: properties, service: nil, version: .v1_1, timestamp: 0, url: "https://example.com", redirect: nil, name: "Example")

        let validator = PasswordValidator(ppd: ppd)

        XCTAssertThrowsError(try validator.validate(password: "Hello123.."))
    }

    func testInconsistentPositionRestriction() {
        var characterSets = [PPDCharacterSet]()
        characterSets.append(PPDCharacterSet(base: .lowerLetters, characters: nil, name: "NameWithTypo"))
        characterSets.append(PPDCharacterSet(base: .upperLetters, characters: "ABCDEFGHIJKLMNOPQRSTUVWXYZ", name: "UpperLetters"))
        characterSets.append(PPDCharacterSet(base: .numbers, characters: nil, name: "Numbers"))
        characterSets.append(PPDCharacterSet(base: .specials, characters: " ", name: "Specials"))

        let positionRestrictions = [PPDPositionRestriction(positions: "0,1,2", minOccurs: 0, maxOccurs: 2, characterSet: "LowerLetters")] // Not present

        let ppdCharacterSettings = PPDCharacterSettings(characterSetSettings: nil, requirementGroups: nil, positionRestrictions: positionRestrictions)
        let properties = PPDProperties(characterSettings: ppdCharacterSettings, maxConsecutive: nil, minLength: nil, maxLength: nil)

        let ppd = PPD(characterSets: characterSets, properties: properties, service: nil, version: .v1_1, timestamp: 0, url: "https://example.com", redirect: nil, name: "Example")

        let validator = PasswordValidator(ppd: ppd)

        XCTAssertThrowsError(try validator.validate(password: "Hello123.."))
    }

    func testInconsistentRequirementGroup() {
        var characterSets = [PPDCharacterSet]()
        characterSets.append(PPDCharacterSet(base: .lowerLetters, characters: nil, name: "NameWithTypo"))
        characterSets.append(PPDCharacterSet(base: .upperLetters, characters: "ABCDEFGHIJKLMNOPQRSTUVWXYZ", name: "UpperLetters"))
        characterSets.append(PPDCharacterSet(base: .numbers, characters: nil, name: "Numbers"))
        characterSets.append(PPDCharacterSet(base: .specials, characters: " ", name: "Specials"))

        var requirementGroups = [PPDRequirementGroup]()
        let rule1 = PPDRequirementRule(positions: nil, minOccurs: 1, maxOccurs: nil, characterSet: "LowerLetters") // Not present
        let rule2 = PPDRequirementRule(positions: nil, minOccurs: 1, maxOccurs: 2, characterSet: "Numbers")
        requirementGroups.append(PPDRequirementGroup(minRules: 2, requirementRules: [rule1, rule2]))

        let ppdCharacterSettings = PPDCharacterSettings(characterSetSettings: nil, requirementGroups: requirementGroups, positionRestrictions: nil)
        let properties = PPDProperties(characterSettings: ppdCharacterSettings, maxConsecutive: nil, minLength: nil, maxLength: nil)

        let ppd = PPD(characterSets: characterSets, properties: properties, service: nil, version: .v1_1, timestamp: 0, url: "https://example.com", redirect: nil, name: "Example")

        let validator = PasswordValidator(ppd: ppd)

        XCTAssertThrowsError(try validator.validate(password: "Hello123.."))
    }

}
