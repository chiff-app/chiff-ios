import XCTest

@testable import keyn

class CryptoTests: XCTestCase {
    
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

    func testDeriveKeyFromSeedDoesntThrow() {
        XCTAssertNoThrow(try Crypto.sharedInstance.deriveKeyFromSeed(seed: seed(), index: 0, context: "0")
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

}
