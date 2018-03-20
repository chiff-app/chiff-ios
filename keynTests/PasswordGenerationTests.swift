//
//  PasswordGenerationTests.swift
//  keynTests
//
//  Created by bas on 08/02/2018.
//  Copyright © 2018 keyn. All rights reserved.
//

import XCTest

@testable import keyn

class PasswordGenerationTests: XCTestCase {

    let commonCharacters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0987654321)(*&^%$#@!{}[]:;\"'?/,.<>`~|"
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.

    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testPasswordGeneration() {
        let site = Site.get(id: 6)!
        let randomIndex = Int(arc4random_uniform(100000000))
        let randomUsername = "TestUsername"
        do {
            let randomPassword = try PasswordGenerator.sharedInstance.generatePassword(username: randomUsername, passwordIndex: randomIndex, siteID: site.id, ppd: site.ppd, offset: nil)
            let offset = try PasswordGenerator.sharedInstance.calculatePasswordOffset(username: randomUsername, passwordIndex: randomIndex, siteID: site.id, ppd: site.ppd, password: randomPassword)
            let calculatedPassword = try PasswordGenerator.sharedInstance.generatePassword(username: randomUsername, passwordIndex: randomIndex, siteID: site.id, ppd: site.ppd, offset: offset)
            XCTAssertEqual(randomPassword, calculatedPassword)
        } catch {

        }
    }

    func testPasswordLength() {
        let ppd = TestHelper.examplePPD(maxConsecutive: 3, minLength: 8, maxLength: 32, characterSetSettings: nil, positionRestrictions: nil, requirementGroups: nil)

        let longPassword = "Ver8aspdisd8nad8*(&sa8d97mjaVer8a" // 33 Characters
        XCTAssertFalse(PasswordGenerator.sharedInstance.validate(password: longPassword, for: ppd))

        let shortPassword = "Sh0rt*r" // 7 characters
        XCTAssertFalse(PasswordGenerator.sharedInstance.validate(password: shortPassword, for: ppd))
    }


    func testSameConsecutiveCharacters() {
        let ppd = TestHelper.examplePPD(maxConsecutive: 3, minLength: 8, maxLength: 32, characterSetSettings: nil, positionRestrictions: nil, requirementGroups: nil)

        let password = "sod8na9p8d7snaaaa" // 4 consecutive characters
        XCTAssertFalse(PasswordGenerator.sharedInstance.validate(password: password, for: ppd))

        let password1 = "sod8na)))9p8d7sn" // 3 consecutive characters
        XCTAssertTrue(PasswordGenerator.sharedInstance.validate(password: password1, for: ppd))
    }

    func testNoConsecutiveCharacterRestriction() {
        let ppd = TestHelper.examplePPD(maxConsecutive: 0, minLength: 8, maxLength: 32, characterSetSettings: nil, positionRestrictions: nil, requirementGroups: nil)

        let password = "sod8na9p8d7snaaaa" // 4 consecutive characters
        XCTAssertTrue(PasswordGenerator.sharedInstance.validate(password: password, for: ppd))

        let ppd2 = TestHelper.examplePPD(maxConsecutive: nil, minLength: 8, maxLength: 32, characterSetSettings: nil, positionRestrictions: nil, requirementGroups: nil)

        XCTAssertTrue(PasswordGenerator.sharedInstance.validate(password: password, for: ppd2))
    }

    func testOrderedConsecutiveCharacters() {
        let ppd = TestHelper.examplePPD(maxConsecutive: 3, minLength: 8, maxLength: 32, characterSetSettings: nil, positionRestrictions: nil, requirementGroups: nil)

        let password = "sod8na9p8d7snabcd" // 4 consecutive characters abcd
        XCTAssertFalse(PasswordGenerator.sharedInstance.checkConsecutiveCharactersOrder(password: password, characters: commonCharacters, maxConsecutive: 3))
        XCTAssertFalse(PasswordGenerator.sharedInstance.validate(password: password, for: ppd))

        let password1 = "sod8na0129p8d7sn" // 3 consecutive characters: 012
        XCTAssertTrue(PasswordGenerator.sharedInstance.checkConsecutiveCharactersOrder(password: password1, characters: commonCharacters, maxConsecutive: 3))
        XCTAssertTrue(PasswordGenerator.sharedInstance.validate(password: password1, for: ppd))
    }

    func testCharacterSetProperties() {
        var characterSetSettings = [PPDCharacterSetSettings]()
        characterSetSettings.append(PPDCharacterSetSettings(minOccurs: nil, maxOccurs: nil, name: "LowerLetters")) // No restrictions on lowerLetters
        characterSetSettings.append(PPDCharacterSetSettings(minOccurs: 1, maxOccurs: nil, name: "UpperLetters")) // At least 1 capital, no max
        characterSetSettings.append(PPDCharacterSetSettings(minOccurs: nil, maxOccurs: 3, name: "Numbers")) // No more than 3 numbers
        characterSetSettings.append(PPDCharacterSetSettings(minOccurs: 1, maxOccurs: 2, name: "Specials")) // 1 or 2 special characters

        let ppd = TestHelper.examplePPD(maxConsecutive: 0, minLength: 8, maxLength: 32, characterSetSettings: characterSetSettings, positionRestrictions: nil, requirementGroups: nil)

        XCTAssertFalse(PasswordGenerator.sharedInstance.validate(password: "asdpudfjkad", for: ppd))
        XCTAssertFalse(PasswordGenerator.sharedInstance.validate(password: "asdpuhfjkad.", for: ppd))
        XCTAssertTrue(PasswordGenerator.sharedInstance.validate(password: "asdpuHfjkad.", for: ppd))

        XCTAssertFalse(PasswordGenerator.sharedInstance.validate(password: "ONLYCAPITALS", for: ppd))
        XCTAssertTrue(PasswordGenerator.sharedInstance.validate(password: "ONL^YCAPITALS", for: ppd))

        XCTAssertTrue(PasswordGenerator.sharedInstance.validate(password: "asdpSd01)fjkad", for: ppd))
        XCTAssertFalse(PasswordGenerator.sharedInstance.validate(password: "a4sdp5Sd0)fj1kad", for: ppd))

        XCTAssertFalse(PasswordGenerator.sharedInstance.validate(password: "asdpuHfjkad", for: ppd))
        XCTAssertTrue(PasswordGenerator.sharedInstance.validate(password: "asdSu12fjk$%ad", for: ppd))
        XCTAssertFalse(PasswordGenerator.sharedInstance.validate(password: "asdS#u12fjk$%ad", for: ppd))
    }

    func testPositionRestrictions() {
        var positionRestrictions = [PPDPositionRestriction]()
        // Comma separated list of character positions the restriction is applied to. Each position can be a character position starting with 0. Negative character positions can be used to specify the position beginning from the end of the password. A value in the interval (0,1) can be used to specify a position by ratio. E.g. 0.5 refers to the center position of the password.
        positionRestrictions.append(PPDPositionRestriction(positions: "0", minOccurs: 1, maxOccurs: nil, characterSet: "UpperLetters")) // Password should start with a captial
        positionRestrictions.append(PPDPositionRestriction(positions: "-1,-2", minOccurs: 1, maxOccurs: 1, characterSet: "Numbers")) // Password should end with 2 numbers (?). Are occurences for the range or per position
        positionRestrictions.append(PPDPositionRestriction(positions: "0.3,0.8", minOccurs: 1, maxOccurs: 3, characterSet: "LowerLetters")) // There should be lower letters on positions 0.3 and 0.8
        positionRestrictions.append(PPDPositionRestriction(positions: "1,-3,0.5", maxOccurs: 2, characterSet: "Specials")) // There should be no more than 2 specials on positions 1, -3 and 0.5
        let ppd = TestHelper.examplePPD(maxConsecutive: nil, minLength: 8, maxLength: 32, characterSetSettings: nil, positionRestrictions: positionRestrictions, requirementGroups: nil)

        // TODO: Write testcases
        XCTFail()
    }

    func testRequirementGroups() {
        var requirementGroups = [PPDRequirementGroup]()

        let rule1 = PPDRequirementRule(positions: "0", minOccurs: 1, maxOccurs: nil, characterSet: "UpperLetters")
        let rule2 = PPDRequirementRule(positions: "-1,-2", minOccurs: 1, maxOccurs: 1, characterSet: "Numbers")
        let rule3 = PPDRequirementRule(positions: "0.3,0.8", minOccurs: 1, maxOccurs: 3, characterSet: "LowerLetters")
        let rule4 = PPDRequirementRule(positions: "1,-3,0.5", maxOccurs: 2, characterSet: "Specials")

        requirementGroups.append(PPDRequirementGroup(minRules: 1, requirementRules: [rule1, rule2]))
        requirementGroups.append(PPDRequirementGroup(minRules: 1, requirementRules: [rule3, rule4]))

        let ppd = TestHelper.examplePPD(maxConsecutive: nil, minLength: 8, maxLength: 32, characterSetSettings: nil, positionRestrictions: nil, requirementGroups: requirementGroups)

        // TODO: Write testcases
        XCTFail()
    }

    
    func testPerformanceExample() {
        // We can test here how long it takes to generate a password with restrictive PPD
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
}
