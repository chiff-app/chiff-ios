/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import XCTest

@testable import keyn

class PasswordGeneratorTests: XCTestCase {

    override func setUp() {
        super.setUp()
        TestHelper.createSeed()
    }

    override func tearDown() {
        super.tearDown()
    }
    
    func testGeneratePasswordShouldReturnPassword() throws {
        let ppd = TestHelper.samplePPD(minLength: 8, maxLength: 32, maxConsecutive: nil, characterSetSettings: nil, positionRestrictions: nil, requirementGroups: nil)
        let passwordGenerator = PasswordGenerator(username: "test", siteId: TestHelper.linkedInPPDHandle, ppd: ppd)
        let (password, index) = try passwordGenerator.generate(index: 0, offset: nil)
        XCTAssertEqual("RMMbQu1QVLIAchpgm7!.<CcL9EM[KFJ(", password)
        XCTAssertEqual(index, 0)
    }
    
    func testCalculatePasswordOffsetShouldResultInSamePassword() throws {
        let site = TestHelper.sampleSite
        let randomIndex = Int(arc4random_uniform(100000000))
        let username = "test"
        let passwordGenerator = PasswordGenerator(username: username, siteId: site.id, ppd: site.ppd)
        let (randomPassword, index) = try passwordGenerator.generate(index: randomIndex, offset: nil)
        
        let offset = try passwordGenerator.calculateOffset(index: index, password: randomPassword)
        let (calculatedPassword, newIndex) = try passwordGenerator.generate(index: index, offset: offset)

        XCTAssertEqual(randomPassword, calculatedPassword)
        XCTAssertEqual(index, newIndex)
    }

    func testCalculatePasswordOffsetThrowsErrorWhenPasswordTooLong() {
        let ppd = TestHelper.samplePPD(minLength: 8, maxLength: 32)
        let password = "Ver8aspdisd8nad8*(&sa8d97mjaVer8a" // 33 Characters
        let passwordGenerator = PasswordGenerator(username: "test", siteId: TestHelper.linkedInPPDHandle, ppd: ppd)
        XCTAssertThrowsError(
            try passwordGenerator.calculateOffset(index: 0, password: password)
        )
    }

    func testCalculatePasswordOffsetThrowsErrorWhenPasswordTooLongUsingFallback() {
        let ppd = TestHelper.samplePPD(minLength: 8, maxLength: nil)
        let password = String(repeating: "a", count: PasswordValidator.MAX_PASSWORD_LENGTH_BOUND + 1)
        let passwordGenerator = PasswordGenerator(username: "test", siteId: TestHelper.linkedInPPDHandle, ppd: ppd)
        XCTAssertThrowsError(
            try passwordGenerator.calculateOffset(index: 0, password: password)
        )
    }
}
