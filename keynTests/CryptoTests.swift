import XCTest

@testable import keyn

class CryptoTests: XCTestCase {

    let linkedInPPDHandle = "c53526a0b5fc33cb7d089d53a45a76044ed5f4aea170956d5799d01b2478cdfa"

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
        Site.get(id: linkedInPPDHandle) { (site) in
            do {
               XCTAssertNoThrow(try PasswordGenerator.sharedInstance.calculatePasswordOffset(username: "user@example.com", passwordIndex: 0, siteID: self.linkedInPPDHandle, ppd: site.ppd, password: "pass123"))
            } catch {
                print("just to suppres compiler warning")
            }
        }
    }

    func testCalculatePasswordOffsetThrowsWhenGenerateKeyThrows() {
        //assert(false, "TODO")
    }

}
