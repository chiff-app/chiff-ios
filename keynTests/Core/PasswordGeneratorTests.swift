/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import XCTest
import LocalAuthentication

@testable import keyn

class PasswordGeneratorTests: XCTestCase {

    override func setUp() {
        super.setUp()
        let exp = expectation(description: "Get an authenticated context")
        LocalAuthenticationManager.shared.authenticate(reason: "Testing", withMainContext: true) { result in
            if case .failure(let error) = result {
                fatalError("Failed to get context: \(error.localizedDescription)")
            }
            TestHelper.createSeed()
            exp.fulfill()
        }
        waitForExpectations(timeout: 40, handler: nil)
    }

    override func tearDown() {
        super.tearDown()
        TestHelper.deleteLocalData()
    }
    
    func testGeneratePasswordShouldReturnPasswordv0() throws {
        let ppd = TestHelper.samplePPD(minLength: 8, maxLength: 32, maxConsecutive: nil, characterSetSettings: nil, positionRestrictions: nil, requirementGroups: nil)
        let passwordGenerator = PasswordGenerator(username: "test", siteId: TestHelper.linkedInPPDHandle, ppd: ppd, passwordSeed: TestHelper.passwordSeed.fromBase64!, version: 0)
        let (password, index) = try passwordGenerator.generate(index: 0, offset: nil)
        XCTAssertEqual("RMMbQu1QVLIAchpgm7!.<CcL9EM[KFJ(", password)
        XCTAssertEqual(index, 0)
    }

    func testGeneratePasswordShouldReturnPasswordv1() throws {
        let ppd = TestHelper.samplePPD(minLength: 8, maxLength: 32, maxConsecutive: nil, characterSetSettings: nil, positionRestrictions: nil, requirementGroups: nil)
        let passwordGenerator = PasswordGenerator(username: "test", siteId: TestHelper.linkedInPPDHandle, ppd: ppd, passwordSeed: TestHelper.passwordSeed.fromBase64!, version: 1)
        let (password, index) = try passwordGenerator.generate(index: 0, offset: nil)
        XCTAssertEqual("}a`]mSI]TRsO@juAxH0YHgDCP<v~THow", password)
        XCTAssertEqual(index, 0)
    }

    func testGeneratePasswordShouldReturnPasswordv0NoPPD() throws {
        let passwordGenerator = PasswordGenerator(username: "test", siteId: TestHelper.linkedInPPDHandle, ppd: nil, passwordSeed: TestHelper.passwordSeed.fromBase64!, version: 0)
        let (password, index) = try passwordGenerator.generate(index: 0, offset: nil)
        XCTAssertEqual("DstZRg8GDZsAxedLasMGbQ", password)
        XCTAssertEqual(index, 0)
    }

    func testGeneratePasswordShouldReturnPasswordv1noPPD() throws {
        let passwordGenerator = PasswordGenerator(username: "test", siteId: TestHelper.linkedInPPDHandle, ppd: nil, passwordSeed: TestHelper.passwordSeed.fromBase64!, version: 1)
        let (password, index) = try passwordGenerator.generate(index: 0, offset: nil)
        XCTAssertEqual("OA0e9zxU8CXjxosttUdcYQ", password)
        XCTAssertEqual(index, 0)
    }

    func testGeneratePasswordReturnsIndexGreaterThan0() {
        var positionRestrictions = [PPDPositionRestriction]()
        // Password should start with a captial
        positionRestrictions.append(PPDPositionRestriction(positions: "0", minOccurs: 1, maxOccurs: nil, characterSet: "UpperLetters"))

        let ppd = TestHelper.samplePPD(minLength: 8, maxLength: 32, maxConsecutive: nil, characterSetSettings: nil, positionRestrictions: positionRestrictions, requirementGroups: nil)
        let passwordGenerator = PasswordGenerator(username: "test", siteId: TestHelper.linkedInPPDHandle, ppd: ppd, passwordSeed: TestHelper.passwordSeed.fromBase64!)
        do {
            let (_, index) = try passwordGenerator.generate(index: 0, offset: nil)
            XCTAssertEqual(index, 3)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testCalculatePasswordOffsetShouldResultInSamePassword() throws {
        let site = TestHelper.sampleSite
        let randomIndex = Int(arc4random_uniform(100000000))
        let username = "test"
        let passwordGenerator = PasswordGenerator(username: username, siteId: site.id, ppd: site.ppd, passwordSeed: TestHelper.passwordSeed.fromBase64!)
        let (randomPassword, index) = try passwordGenerator.generate(index: randomIndex, offset: nil)
        
        let offset = try passwordGenerator.calculateOffset(index: index, password: randomPassword)
        let (calculatedPassword, newIndex) = try passwordGenerator.generate(index: index, offset: offset)

        XCTAssertEqual(randomPassword, calculatedPassword)
        XCTAssertEqual(index, newIndex)
    }

    func testCalculatePasswordOffsetShouldResultInSamePasswordNoPPD() throws {
        let site = TestHelper.sampleSite
        let randomIndex = Int(arc4random_uniform(100000000))
        let username = "test"
        let passwordGenerator = PasswordGenerator(username: username, siteId: site.id, ppd: nil, passwordSeed: TestHelper.passwordSeed.fromBase64!)
        let (randomPassword, index) = try passwordGenerator.generate(index: randomIndex, offset: nil)

        let offset = try passwordGenerator.calculateOffset(index: index, password: randomPassword)
        let (calculatedPassword, newIndex) = try passwordGenerator.generate(index: index, offset: offset)

        XCTAssertEqual(randomPassword, calculatedPassword)
        XCTAssertEqual(index, newIndex)
    }

    func testGeneratePasswordThrowsForMinLengthPPD() {
        let ppd = TestHelper.samplePPD(minLength: 3, maxLength: 7)
        let passwordGenerator = PasswordGenerator(username: "test", siteId: TestHelper.linkedInPPDHandle, ppd: ppd, passwordSeed: TestHelper.passwordSeed.fromBase64!)
        XCTAssertThrowsError(try passwordGenerator.generate(index: 0, offset: nil)) { error in
            XCTAssertEqual(error as! PasswordGenerationError, PasswordGenerationError.tooShort)
        }
    }

    func testGeneratePasswordUseFallbackLengthForMaxLengthPPD() {
        let ppd = TestHelper.samplePPD(minLength: 8, maxLength: 51)
        let passwordGenerator = PasswordGenerator(username: "test", siteId: TestHelper.linkedInPPDHandle, ppd: ppd, passwordSeed: TestHelper.passwordSeed.fromBase64!)
        do {
            let (password, _) = try passwordGenerator.generate(index: 0, offset: nil)
            XCTAssertEqual(password.count, 20)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testDontFailForMissingCharacters() {
        var characterSets = [PPDCharacterSet]()
        characterSets.append(PPDCharacterSet(base: [String](), characters: nil, name: "LowerLetters"))
        characterSets.append(PPDCharacterSet(base: [String](), characters: "ABCDEFGHIJKLMNOPQRSTUVWXYZ", name: "UpperLetters"))
        characterSets.append(PPDCharacterSet(base: [String](), characters: "0123456789", name: "Numbers"))
        characterSets.append(PPDCharacterSet(base: [String](), characters: ")(*&^%$#@!{}[]:;\"'?/,.<>`~|", name: "Specials"))
        let ppd = PPD(characterSets: characterSets, properties: nil, service: nil, version: "1.0", timestamp: Date(timeIntervalSinceNow: 0.0), url: "https://example.com", redirect: nil, name: "Example")
        let passwordGenerator = PasswordGenerator(username: "test", siteId: TestHelper.linkedInPPDHandle, ppd: ppd, passwordSeed: TestHelper.passwordSeed.fromBase64!)
        XCTAssertNoThrow(try passwordGenerator.generate(index: 0, offset: nil))
    }

    func testCalculatePasswordOffsetThrowsErrorWhenPasswordTooShort() {
        let ppd = TestHelper.samplePPD(minLength: 8, maxLength: 32)
        let password = "Ver8aspdisd8nad8*(&sa8d97mjaVer8a" // 33 Characters
        let passwordGenerator = PasswordGenerator(username: "test", siteId: TestHelper.linkedInPPDHandle, ppd: ppd, passwordSeed: TestHelper.passwordSeed.fromBase64!)
        XCTAssertThrowsError(
            try passwordGenerator.calculateOffset(index: 0, password: password)
        )
    }

    func testCalculatePasswordOffsetThrowsErrorWhenPasswordContainsUnallowedCharacter() {
        let ppd = TestHelper.samplePPD(minLength: 8, maxLength: 32)
        let password = "Ver8aspdisd8nad8*(€aVer8a"
        let passwordGenerator = PasswordGenerator(username: "test", siteId: TestHelper.linkedInPPDHandle, ppd: ppd, passwordSeed: TestHelper.passwordSeed.fromBase64!)
        XCTAssertThrowsError(
            try passwordGenerator.calculateOffset(index: 0, password: password)
        ) { error in
            XCTAssertEqual(error as! PasswordGenerationError, PasswordGenerationError.characterNotAllowed)
        }
    }

    func testCalculatePasswordOffsetThrowsErrorWhenPasswordTooLongUsingFallback() {
        let ppd = TestHelper.samplePPD(minLength: 8, maxLength: nil)
        let password = String(repeating: "a", count: PasswordValidator.MAX_PASSWORD_LENGTH_BOUND + 1)
        let passwordGenerator = PasswordGenerator(username: "test", siteId: TestHelper.linkedInPPDHandle, ppd: ppd, passwordSeed: TestHelper.passwordSeed.fromBase64!)
        XCTAssertThrowsError(
            try passwordGenerator.calculateOffset(index: 0, password: password)
        )
    }
}
