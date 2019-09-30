/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import XCTest

@testable import keyn

/*
 * We test the public validate() function for now. In the future
 * we might decide to also test the individual methods but perhaps
 * they will all become private. See Trello issue 187.
 */
class PasswordValidatorTests: XCTestCase {

    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
    }

    func testValidateReturnsFalseWhenMaxLengthExceeded() {
        let ppd = TestHelper.samplePPD(minLength: 8, maxLength: 32)
        let validator = PasswordValidator(ppd: ppd)
        let password = "Ver8aspdisd8nad8*(&sa8d97mjaVer8a" // 33 Characters

        XCTAssertEqual(validator.validate(password: password), false)
    }

    func testValidateReturnsFalseWhenMinLengthUnderceeded() { // is this even a word?
        let ppd = TestHelper.samplePPD(minLength: 8, maxLength: 32)
        let validator = PasswordValidator(ppd: ppd)
        let password = "Sh0rt*r" // 7 characters

        XCTAssertEqual(validator.validate(password: password), false)
    }

    func testValidateReturnsFalseWhenMaxLengthExceededUsingFallback() {
        let ppd = TestHelper.samplePPD(minLength: 8, maxLength: nil)
        let validator = PasswordValidator(ppd: ppd)
        let password = String(repeating: "a", count: PasswordValidator.MAX_PASSWORD_LENGTH_BOUND + 1)

        XCTAssertEqual(validator.validate(password: password), false)
    }

    func testValidateReturnsFalseWhenMinLengthUnderceededUsingFallback() {
        let ppd = TestHelper.samplePPD(minLength: nil, maxLength: 32)
        let validator = PasswordValidator(ppd: ppd)
        let password = String(repeating: "a", count: PasswordValidator.MIN_PASSWORD_LENGTH_BOUND - 1)

        XCTAssertEqual(validator.validate(password: password), false)
    }

    func testValidateReturnsFalseForUnallowedCharacters() {
        let ppd = TestHelper.samplePPD(minLength: 8, maxLength: 32)
        let validator = PasswordValidator(ppd: ppd)

        XCTAssertEqual(validator.validate(password: "Ver8aspdi€sd8na"), false)
    }

    func testValidateReturnsFalseForTooMatestValidateReturnsFalseForUnallowedCharactersnyConsecutiveCharacters() {
        let ppd = TestHelper.samplePPD(minLength: 8, maxLength: 32, maxConsecutive: 3)
        let validator = PasswordValidator(ppd: ppd)
        let password = "sod8na9p8d7snaaaa" // 4 consecutive characters

        XCTAssertEqual(validator.validate(password: password), false)
    }

    func testValidateReturnsFalseForTooManyOrderedConsecutiveCharacters() {
        let ppd = TestHelper.samplePPD(minLength: 8, maxLength: 32, maxConsecutive: 3)
        let validator = PasswordValidator(ppd: ppd)
        let password = "sod8na9p8d7snabcd" // 4 ordered consecutive characters abcd

        XCTAssertEqual(validator.validate(password: password), false)
    }

    // For readability the character sets are defined in Testhelper.examplePPPD().
    func testValidateReturnsFalseWhenCharacterSetMinOccursNotMet() {
        var characterSetSettings = [PPDCharacterSetSettings]()
        characterSetSettings.append(PPDCharacterSetSettings(minOccurs: 1, maxOccurs: nil, name: "UpperLetters"))

        let ppd = TestHelper.samplePPD(minLength: 8, maxLength: 32, maxConsecutive: 0, characterSetSettings: characterSetSettings)
        let validator = PasswordValidator(ppd: ppd)

        XCTAssertEqual(validator.validate(password: "onlylowerletters"), false)
    }

    func testValidateReturnsFalseWhenCharacterSetMaxOccursExceeded() {
        var characterSetSettings = [PPDCharacterSetSettings]()
        characterSetSettings.append(PPDCharacterSetSettings(minOccurs: nil, maxOccurs: 4, name: "UpperLetters"))

        let ppd = TestHelper.samplePPD(minLength: 8, maxLength: 32, maxConsecutive: 0, characterSetSettings: characterSetSettings)
        let validator = PasswordValidator(ppd: ppd)

        XCTAssertEqual(validator.validate(password: "toomanyUPPER"), false)
    }

    func testValidateReturnsFalseIfPositionRestrictionNotMet() {
        var positionRestrictions = [PPDPositionRestriction]()
        // Password should start with a captial
        positionRestrictions.append(PPDPositionRestriction(positions: "0", minOccurs: 1, maxOccurs: nil, characterSet: "UpperLetters"))

        let ppd = TestHelper.samplePPD(minLength: 8, maxLength: 32, maxConsecutive: nil, characterSetSettings: nil, positionRestrictions: positionRestrictions, requirementGroups: nil)
        let validator = PasswordValidator(ppd: ppd)

        XCTAssertEqual(validator.validate(password: "asdpuhfjkad45"), false)
    }

    func testValidateReturnsFalseIfMultiplePositionRestrictionNotMet() {
        var positionRestrictions = [PPDPositionRestriction]()
        // There should be no more than 2 specials combined on positions 1, 2, 3
        positionRestrictions.append(PPDPositionRestriction(positions: "0,1,2", minOccurs: 0, maxOccurs: 2, characterSet: "Specials"))

        let ppd = TestHelper.samplePPD(minLength: 8, maxLength: 32, maxConsecutive: nil, characterSetSettings: nil, positionRestrictions: positionRestrictions, requirementGroups: nil)
        let validator = PasswordValidator(ppd: ppd)

        XCTAssertEqual(validator.validate(password: "**d**********"), true)
        XCTAssertEqual(validator.validate(password: "***puhfjkad45"), false)
    }

    func testValidateShouldReturnFalseIfRequirementGroupIsNotMet() {
        var requirementGroups = [PPDRequirementGroup]()
        let rule1 = PPDRequirementRule(positions: "0", minOccurs: 1, maxOccurs: nil, characterSet: "UpperLetters")
        let rule2 = PPDRequirementRule(positions: "-1,-2", minOccurs: 2, maxOccurs: 2, characterSet: "Numbers")
        requirementGroups.append(PPDRequirementGroup(minRules: 2, requirementRules: [rule1, rule2]))

        let ppd = TestHelper.samplePPD(minLength: 8, maxLength: 32, maxConsecutive: nil, characterSetSettings: nil, positionRestrictions: nil, requirementGroups: requirementGroups)
        let validator = PasswordValidator(ppd: ppd)

        XCTAssertEqual(validator.validate(password: "Password123"), true)  // follows both
        XCTAssertEqual(validator.validate(password: "Password"), false)    // follows rule1 not rule2
        XCTAssertEqual(validator.validate(password: "password123"), false) // follows rule2 not rule1
    }

}
