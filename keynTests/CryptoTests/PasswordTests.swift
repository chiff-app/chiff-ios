/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import XCTest

@testable import keyn

class PasswordTests: XCTestCase {

    let commonCharacters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0987654321)(*&^%$#@!{}[]:;\"'?/,.<>`~|"
    var site: Site!

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
        do {
            TestHelper.createSeed()
            let exp = expectation(description: "Waiting for getting site.")
            try Site.get(id: TestHelper.linkedInPPDHandle, completion: { (site) in
                self.site = site
                exp.fulfill()
            })
            waitForExpectations(timeout: 10, handler: nil)
        } catch {
            XCTFail("An error occured during setup: \(error)")
        }
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testPasswordGeneration() {
        let randomIndex = Int(arc4random_uniform(100000000))
        let randomUsername = "TestUsername"
        do {
            let (randomPassword, index) = try PasswordGenerator.shared.generatePassword(username: randomUsername, passwordIndex: randomIndex, siteID: site.id, ppd: site.ppd, offset: nil)
            let offset = try PasswordGenerator.shared.calculatePasswordOffset(username: randomUsername, passwordIndex: index, siteID: site.id, ppd: site.ppd, password: randomPassword)
            let (calculatedPassword, newIndex) = try PasswordGenerator.shared.generatePassword(username: randomUsername, passwordIndex: index, siteID: site.id, ppd: site.ppd, offset: offset)
            XCTAssertEqual(randomPassword, calculatedPassword)
            XCTAssertEqual(index, newIndex)
        } catch {
            XCTFail("An error occured during password generation: \(error)")
        }
    }

    func testPasswordLength() {
        let ppd = TestHelper.examplePPD(maxConsecutive: nil, minLength: 8, maxLength: 32, characterSetSettings: nil, positionRestrictions: nil, requirementGroups: nil)
        let validator = PasswordValidator(ppd: ppd)

        let longPassword = "Ver8aspdisd8nad8*(&sa8d97mjaVer8a" // 33 Characters
        XCTAssertFalse(validator.validate(password: longPassword))
        XCTAssertThrowsError(try PasswordGenerator.shared.calculatePasswordOffset(username: "demo", passwordIndex: 0, siteID: TestHelper.linkedInPPDHandle, ppd: ppd, password: longPassword))

        let shortPassword = "Sh0rt*r" // 7 characters
        XCTAssertFalse(validator.validate(password: shortPassword))
        XCTAssertThrowsError(try PasswordGenerator.shared.calculatePasswordOffset(username: "demo", passwordIndex: 0, siteID: TestHelper.linkedInPPDHandle, ppd: ppd, password: longPassword))

        let veryLongPassword = "Ver8aspdisd8nad8*(&sa8d97mjaVer8a*(&sa8d97mjaVer8a5" // 51 Characters
        XCTAssertThrowsError(try PasswordGenerator.shared.calculatePasswordOffset(username: "demo", passwordIndex: 0, siteID: TestHelper.linkedInPPDHandle, ppd: ppd, password: veryLongPassword))
    }

    func testDefaultPasswordLength() {
        let ppd = TestHelper.examplePPD(maxConsecutive: nil, minLength: nil, maxLength: nil, characterSetSettings: nil, positionRestrictions: nil, requirementGroups: nil)
        let validator = PasswordValidator(ppd: ppd)

        let longPassword = "Ver8aspdisd8nad8*(&sa8d97mjaVer8a" // 33 Characters
        XCTAssertTrue(validator.validate(password: longPassword))
        XCTAssertNoThrow(try PasswordGenerator.shared.calculatePasswordOffset(username: "demo", passwordIndex: 0, siteID: TestHelper.linkedInPPDHandle, ppd: ppd, password: longPassword))

        let shortPassword = "Sh0rt*r" // 7 characters
        XCTAssertFalse(validator.validate(password: shortPassword))
        XCTAssertNoThrow(try PasswordGenerator.shared.calculatePasswordOffset(username: "demo", passwordIndex: 0, siteID: TestHelper.linkedInPPDHandle, ppd: ppd, password: longPassword))

        let veryLongPassword = "Ver8aspdisd8nad8*(&sa8d97mjaVer8a*(&sa8d97mjaVer8a5" // 51 Characters
        XCTAssertFalse(validator.validate(password: veryLongPassword))
        XCTAssertThrowsError(try PasswordGenerator.shared.calculatePasswordOffset(username: "demo", passwordIndex: 0, siteID: TestHelper.linkedInPPDHandle, ppd: ppd, password: veryLongPassword))
    }

    func testUnallowedCharacters() {
        let ppd = TestHelper.examplePPD(maxConsecutive: nil, minLength: 8, maxLength: 32, characterSetSettings: nil, positionRestrictions: nil, requirementGroups: nil)
        let validator = PasswordValidator(ppd: ppd)

        XCTAssertFalse(validator.validate(password: "Ver8aspdi€sd8na"))
        XCTAssertTrue(validator.validate(password: "Ver8aspdisd8na"))
    }


    func testSameConsecutiveCharacters() {
        let ppd = TestHelper.examplePPD(maxConsecutive: 3, minLength: 8, maxLength: 32, characterSetSettings: nil, positionRestrictions: nil, requirementGroups: nil)
        let validator = PasswordValidator(ppd: ppd)

        let password = "sod8na9p8d7snaaaa" // 4 consecutive characters
        XCTAssertFalse(validator.validate(password: password))

        let password1 = "sod8na)))9p8d7sn" // 3 consecutive characters
        XCTAssertTrue(validator.validate(password: password1))
    }

    func testNoConsecutiveCharacterRestriction() {
        let ppd = TestHelper.examplePPD(maxConsecutive: 0, minLength: 8, maxLength: 32, characterSetSettings: nil, positionRestrictions: nil, requirementGroups: nil)
        let validator = PasswordValidator(ppd: ppd)

        let password = "sod8na9p8d7snaaaa" // 4 consecutive characters
        XCTAssertTrue(validator.validate(password: password))

        let ppd2 = TestHelper.examplePPD(maxConsecutive: nil, minLength: 8, maxLength: 32, characterSetSettings: nil, positionRestrictions: nil, requirementGroups: nil)
        let validator2 = PasswordValidator(ppd: ppd2)

        XCTAssertTrue(validator2.validate(password: password))
    }

    func testOrderedConsecutiveCharacters() {
        let ppd = TestHelper.examplePPD(maxConsecutive: 3, minLength: 8, maxLength: 32, characterSetSettings: nil, positionRestrictions: nil, requirementGroups: nil)
        let validator = PasswordValidator(ppd: ppd)

        let password = "sod8na9p8d7snabcd" // 4 consecutive characters abcd
        XCTAssertFalse(validator.validate(password: password))

        let password1 = "sod8na0129p8d7sn" // 3 consecutive characters: 012
        XCTAssertTrue(validator.validate(password: password1))
    }

    func testCharacterSetProperties() {
        var characterSetSettings = [PPDCharacterSetSettings]()
        characterSetSettings.append(PPDCharacterSetSettings(minOccurs: nil, maxOccurs: nil, name: "LowerLetters")) // No restrictions on lowerLetters
        characterSetSettings.append(PPDCharacterSetSettings(minOccurs: 1, maxOccurs: nil, name: "UpperLetters")) // At least 1 capital, no max
        characterSetSettings.append(PPDCharacterSetSettings(minOccurs: nil, maxOccurs: 3, name: "Numbers")) // No more than 3 numbers
        characterSetSettings.append(PPDCharacterSetSettings(minOccurs: 1, maxOccurs: 2, name: "Specials")) // 1 or 2 special characters

        let ppd = TestHelper.examplePPD(maxConsecutive: 0, minLength: 8, maxLength: 32, characterSetSettings: characterSetSettings, positionRestrictions: nil, requirementGroups: nil)
        let validator = PasswordValidator(ppd: ppd)

        ppd.export()

        XCTAssertFalse(validator.validate(password: "asdpudfjkad"))
        XCTAssertFalse(validator.validate(password: "asdpuhfjkad."))
        XCTAssertTrue(validator.validate(password: "asdpuHfjkad."))

        XCTAssertFalse(validator.validate(password: "ONLYCAPITALS"))
        XCTAssertTrue(validator.validate(password: "ONL^YCAPITALS"))

        XCTAssertTrue(validator.validate(password: "asdpSd01)fjkad"))
        XCTAssertFalse(validator.validate(password: "a4sdp5Sd0)fj1kad"))

        XCTAssertFalse(validator.validate(password: "asdpuHfjkad"))
        XCTAssertTrue(validator.validate(password: "asdSu12fjk$%ad"))
        XCTAssertFalse(validator.validate(password: "asdS#u12fjk$%ad"))
    }

    func testPositionRestrictions() {
        var positionRestrictions = [PPDPositionRestriction]()
        // Comma separated list of character positions the restriction is applied to. Each position can be a character position starting with 0. Negative character positions can be used to specify the position beginning from the end of the password. A value in the interval (0,1) can be used to specify a position by ratio. E.g. 0.5 refers to the center position of the password.
        positionRestrictions.append(PPDPositionRestriction(positions: "0", minOccurs: 1, maxOccurs: nil, characterSet: "UpperLetters")) // Password should start with a captial
        positionRestrictions.append(PPDPositionRestriction(positions: "-1,-2", minOccurs: 2, maxOccurs: 2, characterSet: "Numbers")) // Password should end with 2 numbers (?). Are occurences for the range or per position
        positionRestrictions.append(PPDPositionRestriction(positions: "-8", minOccurs: 1, maxOccurs: 3, characterSet: "LowerLetters")) // There should be lower letters on position 0.5
        positionRestrictions.append(PPDPositionRestriction(positions: "1,-3,2", maxOccurs: 2, characterSet: "Specials")) // There should be no more than 2 specials on positions 1, -3 and 2
        let ppd = TestHelper.examplePPD(maxConsecutive: nil, minLength: 8, maxLength: 32, characterSetSettings: nil, positionRestrictions: positionRestrictions, requirementGroups: nil)
        let validator = PasswordValidator(ppd: ppd)

        XCTAssertFalse(validator.validate(password: "asdpudfjkad"))
        XCTAssertFalse(validator.validate(password: "asdpuhfjkad45"))
        XCTAssertTrue(validator.validate(password: "Asdpughyfjkad45"))

        XCTAssertFalse(validator.validate(password: "Osaydnaoiudsu4"))
        XCTAssertTrue(validator.validate(password: "O&saydnaoiuds(49"))

        XCTAssertFalse(validator.validate(password: "Osay0387103dsu4"))
        XCTAssertTrue(validator.validate(password: "Osaydnaoiudsu(49"))

        XCTAssertTrue(validator.validate(password: "A&sdSufgfjkad^54"))
        XCTAssertFalse(validator.validate(password: "A&*sdSughfjkad#68"))
    }

    func testRequirementGroups() {
        var requirementGroups = [PPDRequirementGroup]()

        let rule1 = PPDRequirementRule(positions: "0", minOccurs: 1, maxOccurs: nil, characterSet: "UpperLetters")
        let rule2 = PPDRequirementRule(positions: "-1,-2", minOccurs: 2, maxOccurs: 2, characterSet: "Numbers")

        let rule3 = PPDRequirementRule(positions: "-8", minOccurs: 1, maxOccurs: 3, characterSet: "LowerLetters")
        let rule4 = PPDRequirementRule(positions: "1,2,-3", maxOccurs: 2, characterSet: "Specials")
        let rule5 = PPDRequirementRule(positions: nil, minOccurs: 1, maxOccurs: nil, characterSet: "Numbers")
        // ADD rules with no position restrictions

        requirementGroups.append(PPDRequirementGroup(minRules: 1, requirementRules: [rule1, rule2]))
        requirementGroups.append(PPDRequirementGroup(minRules: 2, requirementRules: [rule3, rule4, rule5]))

        let ppd = TestHelper.examplePPD(maxConsecutive: nil, minLength: 8, maxLength: 32, characterSetSettings: nil, positionRestrictions: nil, requirementGroups: requirementGroups)
        let validator = PasswordValidator(ppd: ppd)

        XCTAssertFalse(validator.validate(password: "asdpudfjkad"))
        XCTAssertTrue(validator.validate(password: "asdpuhfjkad45"))
        XCTAssertTrue(validator.validate(password: "Asdpuhfjkad"))
        XCTAssertTrue(validator.validate(password: "Asdpughyfjkad45"))

        XCTAssertFalse(validator.validate(password: "A&*sd^*&^*%ad"))
        XCTAssertFalse(validator.validate(password: "A&*sd^*&^*aad"))
        XCTAssertFalse(validator.validate(password: "A&*skashdjk*%ad"))
        XCTAssertTrue(validator.validate(password: "A&*sd^3*&^*aad"))
        XCTAssertTrue(validator.validate(password: "A&skashdjk*%ad"))
    }

    func testPerformanceExample() {

        // We can test here how long it takes to generate a password with restrictive PPD
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
