/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import XCTest
import LocalAuthentication
import PromiseKit

@testable import keyn

class SeedTests: XCTestCase {

    static var context: LAContext!

    override static func setUp() {
        super.setUp()

        if !LocalAuthenticationManager.shared.isAuthenticated {
            LocalAuthenticationManager.shared.authenticate(reason: "Testing", withMainContext: true).done { result in
                context = result
            }.catch { error in
                fatalError("Failed to get context: \(error.localizedDescription)")
            }
        } else {
            context = LocalAuthenticationManager.shared.mainContext
        }

        while context == nil {
            RunLoop.current.run(mode: .default, before: Date.distantFuture)
        }
    }

    override func setUp() {
        super.setUp()
        API.shared = MockAPI()
    }
    
    override func tearDown() {
        super.tearDown()
        TestHelper.deleteLocalData()
    }
    
    // MARK: - Unit Tests
    
    func testCreateSeed() {
        TestHelper.deleteLocalData()
        let expectation = XCTestExpectation(description: "Finish testMnemonic")
        Seed.create(context: Self.context).catch {
            XCTFail($0.localizedDescription)
        }.finally {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)
    }

    func testMnemonic() {
        TestHelper.createSeed()
        let expectation = XCTestExpectation(description: "Finish testMnemonic")
        Seed.mnemonic().done{ (mnemonic) in
            switch Locale.current.languageCode {
            case "nl":
                print(mnemonic)
                XCTAssertEqual(["zucht", "vast", "lans", "troosten", "reclame", "gas", "geen", "blok", "falen", "jammer", "intiem", "kat"], mnemonic)
            default:
                XCTAssertEqual(TestHelper.mnemonic, mnemonic)
            }
        }.catch {
            XCTFail($0.localizedDescription)
        }.finally {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)
    }

    func testMnemonicFailsIfNoData() {
        let expectation = XCTestExpectation(description: "Finish testMnemonicFailsIfNoData")
        TestHelper.deleteLocalData()
        _ = Seed.mnemonic().done { (result) in
             XCTFail("Should fail")
        }.ensure {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)
    }

    func testCreateFailsIfAPIFails() {
        TestHelper.deleteLocalData()
        let mockAPI = MockAPI(shouldFail: true)
        let expectation = XCTestExpectation(description: "Finish testCreateFailsIfAPIFails")
        API.shared = mockAPI
        _ = Seed.create(context: Self.context).done {
            XCTFail("Must fail")
        }.ensure {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)
    }

    func testValidate() {
        TestHelper.createSeed()
        XCTAssertTrue(Seed.validate(mnemonic: TestHelper.mnemonic))
        XCTAssertFalse(Seed.validate(mnemonic: ["Test"]))
    }

    func testRecover() {
        TestHelper.deleteLocalData()
        guard let pubKey = "Sv83e1XwETq4-buTc9fU29lHxCoRPlxA8Xr2pxnXQdI".fromBase64 else {
            return XCTFail("Error getting data from base64 seed")
        }
        let expectation = XCTestExpectation(description: "Finish testRecover")
        API.shared = MockAPI(pubKey: pubKey.base64, account: [TestHelper.userID: TestHelper.userData])
        Seed.recover(context: Self.context, mnemonic: TestHelper.mnemonic).catch {
            XCTFail($0.localizedDescription)
        }.finally {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)
    }

    func testGetPasswordSeedDoesntThrow() {
        TestHelper.createSeed()
        XCTAssertNoThrow(try Seed.getPasswordSeed(context: Self.context))
    }


    func testGetPasswordThrowsIfNoData() {
        TestHelper.deleteLocalData()
        XCTAssertThrowsError(try Seed.getPasswordSeed(context: Self.context))
    }


    func testGetPasswordSeed() {
        TestHelper.createSeed()
        do {
            let passwordSeed = try Seed.getPasswordSeed(context: Self.context)
            XCTAssertEqual(passwordSeed.base64, "L0y8UIj15Tl2jm2k5cZU8avW45GzOQi4kpHD-PdrAT0")
        } catch {
            XCTFail("Error getting password seed: \(error)")
        }
    }

    func testGetBackupSeedDoesntThrow() {
        TestHelper.createSeed()
        XCTAssertNoThrow(try Seed.getBackupSeed(context: Self.context))
    }

    func testGetBackupThrowsIfNoData() {
        TestHelper.deleteLocalData()
        XCTAssertThrowsError(try Seed.getBackupSeed(context: Self.context))
    }

    func testGetBackupSeed() {
        TestHelper.createSeed()
        do {
            let backupSeed = try Seed.getBackupSeed(context: Self.context)
            XCTAssertEqual(backupSeed.base64, "bOqw6X0TH1Xp5jh9eX2KkoLX6wDsgqbFg5-E-cJhAYw")
        } catch {
            XCTFail("Error getting password seed: \(error)")
        }
    }

    func testDelete() {
        Keychain.shared.deleteAll(service: .seed)
        TestHelper.createSeed()
        XCTAssertNoThrow(Seed.delete())
    }


    func testDeleteBackupData() {
        TestHelper.createSeed()
        let expectation = XCTestExpectation(description: "Finish testDeleteBackupData")
        Seed.deleteBackupData().catch {
            XCTFail($0.localizedDescription)
        }.finally {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)
    }

    func testDeleteBackupDataFailsIfAPIFails() {
        TestHelper.createSeed()
        API.shared = MockAPI(pubKey: try! Seed.publicKey(), account: [TestHelper.userID: TestHelper.userData], shouldFail: true)
        let expectation = XCTestExpectation(description: "Finish testDeleteBackupDataFailsIfAPIFails")
        _ = Seed.deleteBackupData().done {
            XCTFail("Should fail")
        }.ensure {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)
    }

    func testSetBackedUp() {
        TestHelper.createSeed()
        UserDefaults.standard.set(false, forKey: "paperBackupCompleted")
        XCTAssertFalse(Seed.paperBackupCompleted)
        Seed.paperBackupCompleted = true
        XCTAssertTrue(Seed.paperBackupCompleted)
    }

    func testIsBackedUp() {
        TestHelper.deleteLocalData()
        guard let pubKey = "Sv83e1XwETq4-buTc9fU29lHxCoRPlxA8Xr2pxnXQdI".fromBase64 else {
            return XCTFail("Error getting data from base64 seed")
        }
        API.shared = MockAPI(pubKey: pubKey.base64, account: [TestHelper.userID: TestHelper.userData])
        let expectation = XCTestExpectation(description: "Finish testIsBackedUp")
        Seed.recover(context: Self.context, mnemonic: TestHelper.mnemonic).done { (result) in
            guard let account = try UserAccount.get(id: TestHelper.userID, context: Self.context) else {
                return XCTFail("Account not found")
            }
            XCTAssertTrue(account.id == TestHelper.userID)
        }.catch {
            XCTFail($0.localizedDescription)
        }.finally {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10.0)
    }

    func testPublicKey() {
        TestHelper.createSeed()
        do {
            let publicKey = try Seed.publicKey()
            XCTAssertEqual(publicKey, "Sv83e1XwETq4-buTc9fU29lHxCoRPlxA8Xr2pxnXQdI")
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testPrivateKeyDoesntThrow() {
        TestHelper.createSeed()
        XCTAssertNoThrow(try Seed.privateKey())
    }

    func testPrivateKey() {
        TestHelper.createSeed()
        do {
            let privateKey = try Seed.privateKey()
            guard let constantKey = TestHelper.backupPrivKey.fromBase64 else {
                return XCTFail("Imposible to get data from base64 string")
            }
            XCTAssertEqual(privateKey, constantKey)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    // MARK: - Integration Tests

    func testCreateAndMnemonicAndValidateAndDeleteAndRecover() {
        TestHelper.deleteLocalData()
        let expectation = XCTestExpectation(description: "Finish testCreateAndMnemonicAndValidateAndDeleteAndRecover")
        Seed.create(context: Self.context).then { (seedResult) in
            Seed.mnemonic()
        }.then { (mnemonic: [String]) -> Promise<(Int,Int,Int,Int)> in
            XCTAssertTrue(Seed.validate(mnemonic: mnemonic))
            TestHelper.deleteLocalData()
            return Seed.recover(context: Self.context, mnemonic: mnemonic)
        }.catch {
            XCTFail($0.localizedDescription)
        }.finally {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)
    }
}
