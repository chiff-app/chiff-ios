import XCTest

@testable import keyn

class CryptoTests: XCTestCase {

    let restrictions = TestHelper.examplePasswordRestrictions()

    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }

    private func seed() -> Data {
        return try! Crypto.sharedInstance.generateSeed()
    }

    func testGenerateSeedDoesntThrow() {
        XCTAssertNoThrow(try Crypto.sharedInstance.generateSeed())
    }

    func testGenerateReturnsSeedWithCorrectType() throws {
        let seed = try Crypto.sharedInstance.generateSeed()
        assert((seed as Any) is Data)
    }

    func testGenerateReturnsSeedWithCorrectLength() throws {
        let seed = try Crypto.sharedInstance.generateSeed()
        XCTAssertEqual(seed.count, 16)
    }

    func testDeriveKeyFromSeedDoesntThrow() {
        XCTAssertNoThrow(try Crypto.sharedInstance.deriveKeyFromSeed(seed: seed(), keyType: .passwordSeed, context: "0")
        )
    }

    func testDeriveKeyFromSeedThrowsCryptoErrorHashingWhenSodiumHashFails() {
//        CryptoError.hashing
        XCTAssertTrue(false)
    }

    func testDeriveKeyFromSeedThrowsCryptoErrorKeyDerivationWhenSodiumDeriveFails() {
//        CryptoError.keyDerivation
        XCTAssertTrue(false)
    }

    func testCalculatePasswordOffsetDoesntThrow() {
        XCTAssertNoThrow(try Crypto.sharedInstance.calculatePasswordOffset(username: "user@example.com", passwordIndex: 0, siteID: "0", restrictions: restrictions, password: "pass123"))
    }

    func testCalculatePasswordOffsetThrowsWhenGenerateKeyThrows() {
        assert(false, "TODO")
    }

}
