/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import XCTest
import LocalAuthentication

@testable import keyn

class SeedTests: XCTestCase {

    override func setUp() {
        super.setUp()
        TestHelper.createSeed()
        API.shared = MockAPI()
    }
    
    override func tearDown() {
        super.tearDown()
        TestHelper.deleteLocalData()
    }
    
    // MAKR: - Unit Tests
    
    func testCreateSeed() {
        TestHelper.deleteLocalData()
        Seed.create(context: nil) { (result) in
            if case let .failure(error) = result {
                XCTFail(error.localizedDescription)
            }
        }
    }

    func testMnemonic() {
        let expectation = XCTestExpectation(description: "Finish testMnemonic")
        Seed.mnemonic { (result) in
            switch result {
            case .success(let mnemonic):
                switch Locale.current.languageCode {
                case "nl":
                    print(mnemonic)
                    XCTAssertEqual(["zucht", "vast", "lans", "troosten", "reclame", "gas", "geen", "blok", "falen", "jammer", "intiem", "kat"], mnemonic)
                default:
                    XCTAssertEqual(TestHelper.mnemonic, mnemonic)
                }
                expectation.fulfill()
            case .failure(let error):
                XCTFail(error.localizedDescription)
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 3.0)
    }

    func testMnemonicFailsIfNoData() {
        let expectation = XCTestExpectation(description: "Finish testMnemonicFailsIfNoData")
        TestHelper.deleteLocalData()
        Seed.mnemonic { (result) in
            if case .success(_) = result {
                XCTFail("Should fail")
            }
            expectation.fulfill()
        }
         wait(for: [expectation], timeout: 3.0)
    }

    func testValidate() {
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
        Seed.recover(context: LAContext(), mnemonic: TestHelper.mnemonic) { (result) in
            if case let .failure(error) = result {
                XCTFail(error.localizedDescription)
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)
    }

    func testGetPasswordSeedDoesntThrow() {
        let context = LAContext()
        let expectation = XCTestExpectation(description: "Finish testGetPasswordSeedDoesntThrow")
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Testing") { (_, _) in
            do {
                XCTAssertNoThrow(try Seed.getPasswordSeed(context: context))
            } catch let error {
                XCTFail(error.localizedDescription)
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10.0)
    }

    func testGetPasswordThrowsIfNoData() {
        TestHelper.deleteLocalData()
        let context = LAContext()
        let expectation = XCTestExpectation(description: "Finish testGetPasswordThrowsIfNoData")
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Testing") { (_, _) in
            do {
                try Seed.getPasswordSeed(context: context)
            } catch let error {
                XCTAssertEqual(error.localizedDescription, KeychainError.notFound.localizedDescription)
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10.0)
    }

    func testGetPasswordSeed() {
        let context = LAContext()
        let expectation = XCTestExpectation(description: "Finish testGetPasswordSeed")
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Testing") { (_, _) in
            do {
                let passwordSeed = try Seed.getPasswordSeed(context: context)
                XCTAssertEqual(passwordSeed.base64, "L0y8UIj15Tl2jm2k5cZU8avW45GzOQi4kpHD-PdrAT0")
            } catch {
                XCTFail("Error getting password seed: \(error)")
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10.0)
    }

    func testGetBackupSeedDoesntThrow() {
        let context = LAContext()
        let expectation = XCTestExpectation(description: "Finish testGetBackupSeedDoesntThrow")
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Testing") { (_, _) in
            do {
                XCTAssertNoThrow(try Seed.getBackupSeed(context: context))
            } catch {
                XCTFail("Error getting password seed: \(error)")
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10.0)
    }

    func testGetBackupThrowsIfNoData() {
        TestHelper.deleteLocalData()
        XCTAssertThrowsError(try Seed.getBackupSeed(context: nil))
    }

    func testGetBackupSeed() {
        let context = LAContext()
        let expectation = XCTestExpectation(description: "Finish testGetBackupSeed")
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Testing") { (_, _) in
            do {
                let backupSeed = try Seed.getBackupSeed(context: context)
                XCTAssertEqual(backupSeed.base64, "bOqw6X0TH1Xp5jh9eX2KkoLX6wDsgqbFg5-E-cJhAYw")
            } catch {
                XCTFail("Error getting password seed: \(error)")
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10.0)
    }

    func testDelete() {
        XCTAssertNoThrow(try Seed.delete())
    }
    
    func testDeleteThrowsIfNoData() {
        TestHelper.deleteLocalData()
        XCTAssertThrowsError(try Seed.delete())
    }

    func testSetBackedUp() {
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
        LocalAuthenticationManager.shared.authenticate(reason: "Testing", withMainContext: true) { (result) in
            switch result {
            case .failure(let error):
                XCTFail(error.localizedDescription)
                expectation.fulfill()
            case .success(let context):
                Seed.recover(context: context!, mnemonic: TestHelper.mnemonic) { (result) in
                    do {
                        let _ = try result.get()
                        guard let account = try Account.get(accountID: TestHelper.userID, context: context) else {
                            return XCTFail("Account not found")
                        }
                        XCTAssertTrue(account.id == TestHelper.userID)
                    } catch {
                        XCTFail(error.localizedDescription)
                    }
                    expectation.fulfill()
                }
            }
        }
        wait(for: [expectation], timeout: 10.0)
    }

    // MARK: - Integration Tests

    func testCreateAndMnemonicAndValidateAndDeleteAndRecover() {
        TestHelper.deleteLocalData()
        let expectation = XCTestExpectation(description: "Finish testCreateAndMnemonicAndValidateAndDeleteAndRecover")
        Seed.create(context: LAContext()) { (seedResult) in
            switch seedResult {
            case .success(_):
                Seed.mnemonic { (result) in
                    do {
                        let mnemonic = try result.get()
                        XCTAssertTrue(Seed.validate(mnemonic: mnemonic))
                        TestHelper.deleteLocalData()
                        Seed.recover(context: LAContext(), mnemonic: mnemonic, completionHandler: { (result) in
                            if case let .failure(error) = result {
                                XCTFail(error.localizedDescription)
                            }
                            expectation.fulfill()
                        })
                    } catch {
                        XCTFail("Error deleting seeds \(error)")
                        expectation.fulfill()
                    }
                }
            case .failure(let error):
                XCTFail(error.localizedDescription)
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 3.0)
    }
}
