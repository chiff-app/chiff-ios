/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import XCTest

@testable import keyn

class PasswordGeneratorTests: XCTestCase {

    override func setUp() {
        super.setUp()
        TestHelper.setUp()
    }

    override func tearDown() {
        super.tearDown()
        TestHelper.tearDown()
    }
    
    func testGeneratePasswordShouldReturnPassword() throws {
        let ppd = TestHelper.examplePPD(minLength: 8, maxLength: 32, maxConsecutive: nil, characterSetSettings: nil, positionRestrictions: nil, requirementGroups: nil)

        let (password, index) = try PasswordGenerator.shared.generatePassword(username: "test", passwordIndex: 0, siteID: TestHelper.linkedInPPDHandle, ppd: ppd, offset: nil)
        XCTAssertEqual(password, "Q{S/(jaT5w#PFAuaP`'QpAyod#UHA[}w")
        XCTAssertEqual(index, 0)
    }
    
    func testCalculatePasswordOffsetShouldResultInSamePassword() throws {
        let site = TestHelper.testSite
        let randomIndex = Int(arc4random_uniform(100000000))
        let username = "test"

        let (randomPassword, index) = try PasswordGenerator.shared.generatePassword(username: username, passwordIndex: randomIndex, siteID: site.id, ppd: site.ppd, offset: nil)
        let offset = try PasswordGenerator.shared.calculatePasswordOffset(username: username, passwordIndex: index, siteID: site.id, ppd: site.ppd, password: randomPassword)
        let (calculatedPassword, newIndex) = try PasswordGenerator.shared.generatePassword(username: username, passwordIndex: index, siteID: site.id, ppd: site.ppd, offset: offset)

        XCTAssertEqual(randomPassword, calculatedPassword)
        XCTAssertEqual(index, newIndex)
    }

    func testCalculatePasswordOffsetThrowsErrorWhenPasswordTooLong() {
        let ppd = TestHelper.examplePPD(minLength: 8, maxLength: 32)
        let password = "Ver8aspdisd8nad8*(&sa8d97mjaVer8a" // 33 Characters

        XCTAssertThrowsError(
            try PasswordGenerator.shared.calculatePasswordOffset(username: "test", passwordIndex: 0, siteID: TestHelper.linkedInPPDHandle, ppd: ppd, password: password)
        )
    }

    func testCalculatePasswordOffsetThrowsErrorWhenPasswordTooLongUsingFallback() {
        let ppd = TestHelper.examplePPD(minLength: 8, maxLength: nil)
        let password = String(repeating: "a", count: PasswordValidator.MAX_PASSWORD_LENGTH_BOUND + 1)
        XCTAssertThrowsError(
            try PasswordGenerator.shared.calculatePasswordOffset(username: "test", passwordIndex: 0, siteID: TestHelper.linkedInPPDHandle, ppd: ppd, password: password)
        )
    }
}
