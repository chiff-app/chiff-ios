import XCTest

@testable import keyn

class CryptoTests: XCTestCase {
    
    var site: Site!

    override func setUp() {
        super.setUp()
        do {
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
        super.tearDown()
    }

    func testGenerateSeedDoesntThrow() {
        XCTAssertNoThrow(try Crypto.sharedInstance.generateSeed())
    }

    func testGenerateReturnsSeedWithCorrectType() {
        do {
            let seed = try Crypto.sharedInstance.generateSeed()
            XCTAssert((seed as Any) is Data)
        } catch {
            XCTFail("Error during seed generation: \(error)")
        }
    }

    func testGenerateReturnsSeedWithCorrectLength() {
        do {
            let seed = try Crypto.sharedInstance.generateSeed()
            XCTAssertEqual(seed.count, 16)
        } catch {
            XCTFail("Error during seed generation: \(error)")
        }
    }

    func testDeriveKeyFromSeedDoesntThrow() {
        do {
            let seed = try Crypto.sharedInstance.generateSeed()
            XCTAssertNoThrow(try Crypto.sharedInstance.deriveKeyFromSeed(seed: seed, keyType: .passwordSeed, context: "0")
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
