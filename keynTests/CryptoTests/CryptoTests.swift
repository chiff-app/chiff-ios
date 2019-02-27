/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import XCTest

@testable import keyn

class CryptoTests: XCTestCase {
    var site: Site!

    override func setUp() {
        super.setUp()
        do {
            let exp = expectation(description: "Waiting for getting site.")
            try Site.get(id: TestHelper.linkedInPPDHandle) { (site) in
                self.site = site
                exp.fulfill()
            }
            waitForExpectations(timeout: 10, handler: nil)
        } catch {
            XCTFail("An error occured during setup: \(error)")
        }
    }
    
    override func tearDown() {
        super.tearDown()
    }

    func testGenerateSeedDoesntThrow() {
        XCTAssertNoThrow(try Crypto.shared.generateSeed())
    }

    func testGenerateReturnsSeedWithCorrectType() {
        do {
            let seed = try Crypto.shared.generateSeed()
            XCTAssert((seed as Any) is Data)
        } catch {
            XCTFail("Error during seed generation: \(error)")
        }
    }

    func testGenerateReturnsSeedWithCorrectLength() {
        do {
            let seed = try Crypto.shared.generateSeed()
            XCTAssertEqual(seed.count, 16)
        } catch {
            XCTFail("Error during seed generation: \(error)")
        }
    }

    func testDeriveKeyFromSeedDoesntThrow() {
        do {
            let seed = try Crypto.shared.generateSeed()
            XCTAssertNoThrow(try Crypto.shared.deriveKeyFromSeed(seed: seed, keyType: .passwordSeed, context: "0")
            )
        } catch {
            XCTFail("Error during seed generation: \(error)")
        }
    }
    
    func testCreateSessionKeyPairDoesntThrow() {

    }
    
    func testCreateSigningKeyPairDoesntThrow() {

    }
    
    func testDeterministicRandomBytes() {

    }
    
    func testDeterministicRandomBytesWithCustomLength() {

    }
    
    func testDeriveKey() {

    }
    
    func testConvertToBase64() {

    }
    
    func testConvertFromBase64() {

    }
    
    func testSign() {

    }
    
    func testEncryptSymmetric() {

    }
    
    func testDecryptSymmetric() {

    }
    
    func testEncryptAndDecryptSymmetric() {

    }
    
    func testEncryptAssymetric() {

    }
    
    func testDecryptAssymetric() {

    }
    
    func testEncryptAndDecryptAssymetric() {

    }
    
    func testHashFromData() {

    }
    
    func testHashFromString() {

    }
}
