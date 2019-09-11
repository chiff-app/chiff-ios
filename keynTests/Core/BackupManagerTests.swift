/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import XCTest

@testable import keyn

class BackupManagerTests: XCTestCase {

    override func setUp() {
        super.setUp()
        TestHelper.createSeed()
        TestHelper.createBackupKeys()
        API.shared = MockAPI()
    }

    override func tearDown() {
        super.tearDown()
        TestHelper.deleteLocalData()
    }

    // MARK: - Unit tests
    
    func testInitializeIfKeysAlreadyExist() {
        let expectation = XCTestExpectation(description: "Finish testInitializeFailsIfKeysAlreadyExist")
        do {
            let backupSeed = try Keychain.shared.get(id: KeyIdentifier.backup.identifier(for: .seed), service: .seed)
            BackupManager.shared.initialize(seed: backupSeed, context: FakeLAContext()) { (result) in
                if case let .failure(error) = result {
                    XCTFail(error.localizedDescription)
                }
                expectation.fulfill()
            }
        } catch {
            XCTFail(error.localizedDescription)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)
    }

    func testInitializeDoesntFail() {
        TestHelper.deleteLocalData()
        TestHelper.createSeed()
        let expectation = XCTestExpectation(description: "Finish testInitializeDoesntFail")
        do {
            let backupSeed = try Keychain.shared.get(id: KeyIdentifier.backup.identifier(for: .seed), service: .seed)
            BackupManager.shared.initialize(seed: backupSeed, context: FakeLAContext()) { (result) in
                if case let .failure(error) = result {
                    XCTFail(error.localizedDescription)
                }
                expectation.fulfill()
            }
        } catch {
            XCTFail(error.localizedDescription)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)
    }
    
    func testInitializeFailsIfWrongSeed() {
        TestHelper.deleteLocalData()
        TestHelper.createSeed()
        let expectation = XCTestExpectation(description: "Finish testInitializeFailsIfWrongSeed")
        let backupSeed = "seed".data
        BackupManager.shared.initialize(seed: backupSeed, context: FakeLAContext()) { (result) in
            if case .success(_) = result {
                XCTFail("Should fail")
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)
    }
    
    func testInitializeFailsIfAPIFails() {
        TestHelper.deleteLocalData()
        TestHelper.createSeed()
        let mockAPI = MockAPI(shouldFail: true)
        let expectation = XCTestExpectation(description: "Finish testInitializeFailsIfAPIFails")
        API.shared = mockAPI
        do {
            let backupSeed = try Keychain.shared.get(id: KeyIdentifier.backup.identifier(for: .seed), service: .seed)
            BackupManager.shared.initialize(seed: backupSeed, context: FakeLAContext()) { (result) in
                if case .success(_) = result {
                    XCTFail("Should fail")
                }
                expectation.fulfill()
            }
        } catch {
            XCTFail(error.localizedDescription)
        }
        wait(for: [expectation], timeout: 3.0)
    }
    
    func testBackup() {
        let site = TestHelper.sampleSite
        let expectation = XCTestExpectation(description: "Finish testBackup")
        let account = Account(id: TestHelper.userID, username: TestHelper.username, sites: [site], passwordIndex: 0, lastPasswordTryIndex: 0, passwordOffset: nil, askToLogin: nil, askToChange: nil, enabled: false, version: 1)
        let backupAccount = BackupAccount(account: account, tokenURL: nil, tokenSecret: nil)
        BackupManager.shared.backup(account: backupAccount) { (result) in
            XCTAssertTrue(result)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)
    }
    
    func testBackupFailsIfAPIFails() {
        let site = TestHelper.sampleSite
        let mockAPI = MockAPI(shouldFail: true)
        API.shared = mockAPI
        let expectation = XCTestExpectation(description: "Finish testBackupFailsIfAPIFails")
        let account = Account(id: TestHelper.userID, username: TestHelper.username, sites: [site], passwordIndex: 0, lastPasswordTryIndex: 0, passwordOffset: nil, askToLogin: nil, askToChange: nil, enabled: false, version: 1)
        let backupAccount = BackupAccount(account: account, tokenURL: nil, tokenSecret: nil)
        BackupManager.shared.backup(account: backupAccount) { (result) in
            XCTAssertFalse(result)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)
    }

    func testDeleteAccount() {
        do {
            let pubKey = try Keychain.shared.get(id: KeyIdentifier.pub.identifier(for: .backup), service: .backup)
            let mockAPI = MockAPI(pubKey: pubKey.base64, account: [TestHelper.userID: TestHelper.userData])
            API.shared = mockAPI
            let originalSize = mockAPI.mockData[pubKey.base64]!.count
            try BackupManager.shared.deleteAccount(accountId: TestHelper.userID)
            XCTAssertTrue(mockAPI.mockData[pubKey.base64]!.count < originalSize)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    func testDeleteAccountFailsIfAPIFails() {
        do {
            let pubKey = try Keychain.shared.get(id: KeyIdentifier.pub.identifier(for: .backup), service: .backup)
            let mockAPI = MockAPI(pubKey: pubKey.base64, account: [TestHelper.userID: TestHelper.userData], shouldFail: true)
            API.shared = mockAPI
            let originalSize = mockAPI.mockData[pubKey.base64]!.count
            try BackupManager.shared.deleteAccount(accountId: TestHelper.userID)
            XCTAssertFalse(mockAPI.mockData[pubKey.base64]!.count < originalSize)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testDeleteAllAccounts() {
        let expectation = XCTestExpectation(description: "Finish testDeleteAllAccounts")
        do {
            let pubKey = try Keychain.shared.get(id: KeyIdentifier.pub.identifier(for: .backup), service: .backup)
            API.shared = MockAPI(pubKey: pubKey.base64, account: [TestHelper.userID: TestHelper.userData])
            BackupManager.shared.deleteAllAccounts(completionHandler: { (result) in
                if case let .failure(error) = result {
                    XCTFail(error.localizedDescription)
                }
                expectation.fulfill()
            })
        } catch {
            XCTFail("Failed getting pubKey")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)
    }
    
    func testDeleteAllAccountsFailsIfAPIFails() {
        let expectation = XCTestExpectation(description: "Finish testDeleteAllAccountsFailsIfAPIFails")
        do {
            let pubKey = try Keychain.shared.get(id: KeyIdentifier.pub.identifier(for: .backup), service: .backup)
            let mockAPI = MockAPI(pubKey: pubKey.base64, account: [TestHelper.userID: TestHelper.userData], shouldFail: true)
            API.shared = mockAPI
            BackupManager.shared.deleteAllAccounts(completionHandler: { (result) in
                if case .success(_) = result {
                    XCTFail("Should fail")
                }
                expectation.fulfill()
            })
        } catch {
            XCTFail("Failed getting pubKey")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)
    }
    
    func testDeleteAllAccountsFailsIfNoPrivateKey() {
        let expectation = XCTestExpectation(description: "Finish testDeleteAllAccountsFailsIfNoPrivateKey")
        do {
            let pubKey = try Keychain.shared.get(id: KeyIdentifier.pub.identifier(for: .backup), service: .backup)
            API.shared = MockAPI(pubKey: pubKey.base64, account: [TestHelper.userID: TestHelper.userData])
            TestHelper.deleteLocalData()
            BackupManager.shared.deleteAllAccounts(completionHandler: { (result) in
                if case .success(_) = result {
                    XCTFail("Should fail")
                }
                expectation.fulfill()
            })
        } catch {
            XCTFail("Failed getting pubKey")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)
    }

    func testGetBackupData() {
        let expectation = XCTestExpectation(description: "Finish testGetBackupData")
        do {
            let seed = try Keychain.shared.get(id: KeyIdentifier.backup.identifier(for: .seed), service: .seed)
            let pubKey = try Keychain.shared.get(id: KeyIdentifier.pub.identifier(for: .backup), service: .backup)
            API.shared = MockAPI(pubKey: pubKey.base64, account: [TestHelper.userID: TestHelper.userData])
            try BackupManager.shared.getBackupData(seed: seed, context: FakeLAContext()) { (result) in
                if case let .failure(error) = result {
                    XCTFail(error.localizedDescription)
                }
                expectation.fulfill()
            }
        } catch {
            XCTFail(error.localizedDescription)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)
    }
    
    func testGetBackupDataFailsIfAPIFails() {
        let expectation = XCTestExpectation(description: "Finish testGetBackupDataFailsIfAPIFails")
        do {
            let seed = try Keychain.shared.get(id: KeyIdentifier.backup.identifier(for: .seed), service: .seed)
            let pubKey = try Keychain.shared.get(id: KeyIdentifier.pub.identifier(for: .backup), service: .backup)
            let mockAPI = MockAPI(pubKey: pubKey.base64, account: [TestHelper.userID: TestHelper.userData], shouldFail: true)
            API.shared = mockAPI
            try BackupManager.shared.getBackupData(seed: seed, context: FakeLAContext()) { (result) in
                if case .success(_) = result {
                    XCTFail("Should fail")
                }
                expectation.fulfill()
            }
        } catch {
            XCTFail(error.localizedDescription)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)
    }
    
    func testGetBackupDataIfNoPubKey() {
        TestHelper.deleteLocalData()
        TestHelper.createSeed()
        let expectation = XCTestExpectation(description: "Finish testGetBackupDataIfNoPubKey")
        do {
            let seed = try Keychain.shared.get(id: KeyIdentifier.backup.identifier(for: .seed), service: .seed)
            try BackupManager.shared.getBackupData(seed: seed, context: FakeLAContext()) { (result) in
                if case let .failure(error) = result {
                    XCTFail(error.localizedDescription)
                }
                expectation.fulfill()
            }
        } catch {
            XCTFail(error.localizedDescription)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)
    }

    func testPublicKeyDoesntThrow() {
        XCTAssertNoThrow(try BackupManager.shared.publicKey())
    }

    func testPublicKey() {
        do {
            let publicKey = try BackupManager.shared.publicKey()
            XCTAssertEqual(publicKey, "Sv83e1XwETq4-buTc9fU29lHxCoRPlxA8Xr2pxnXQdI")
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testPrivateKeyDoesntThrow() {
        XCTAssertNoThrow(try BackupManager.shared.privateKey())
    }

    func testPrivateKey() {
        do {
            let privateKey = try BackupManager.shared.privateKey()
            guard let constantKey = "bOqw6X0TH1Xp5jh9eX2KkoLX6wDsgqbFg5-E-cJhAYxK_zd7VfAROrj5u5Nz19Tb2UfEKhE-XEDxevanGddB0g".fromBase64 else {
                return XCTFail("Imposible to get data from base64 string")
            }
            XCTAssertEqual(privateKey, constantKey)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    // MARK: - Integration tests

    func testBackupAndDeleteAccount() {
        let mockAPI = API.shared as! MockAPI
        let site = TestHelper.sampleSite
        let expectation = XCTestExpectation(description: "Finish testBackupAndDeleteAccount")
        let account = Account(id: TestHelper.userID, username: TestHelper.username, sites: [site], passwordIndex: 0, lastPasswordTryIndex: 0, passwordOffset: nil, askToLogin: nil, askToChange: nil, enabled: false, version: 1)
        let backupAccount = BackupAccount(account: account, tokenURL: nil, tokenSecret: nil)
        BackupManager.shared.backup(account: backupAccount) { (result) in
            XCTAssertTrue(result)
            do {
                let pubKey = try Keychain.shared.get(id: KeyIdentifier.pub.identifier(for: .backup), service: .backup)
                let originalSize = mockAPI.mockData[pubKey.base64]!.count
                try BackupManager.shared.deleteAccount(accountId: TestHelper.userID)
                XCTAssertTrue(mockAPI.mockData[pubKey.base64]!.count < originalSize)
                expectation.fulfill()
            } catch {
                XCTFail(error.localizedDescription)
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 3.0)
    }

    func testBackupAndDeleteAllAccounts() {
        let site = TestHelper.sampleSite
        let expectation = XCTestExpectation(description: "Finish testBackupAndDeleteAllAccounts")
        let account = Account(id: TestHelper.userID, username: TestHelper.username, sites: [site], passwordIndex: 0, lastPasswordTryIndex: 0, passwordOffset: nil, askToLogin: nil, askToChange: nil, enabled: false, version: 1)
        let backupAccount = BackupAccount(account: account, tokenURL: nil, tokenSecret: nil)
        BackupManager.shared.backup(account: backupAccount) { (result) in
            XCTAssertTrue(result)
            BackupManager.shared.deleteAllAccounts(completionHandler: { (result) in
                if case let .failure(error) = result {
                    XCTFail(error.localizedDescription)
                }
                expectation.fulfill()
            })
        }
        wait(for: [expectation], timeout: 3.0)
    }

    func testBackupAndGetBackupData() {
        // Assure there currently no accounts in the Keychain
        Account.deleteAll()
        let site = TestHelper.sampleSite
        let expectation = XCTestExpectation(description: "Finish testBackupAndGetBackupData")
        let account = Account(id: TestHelper.userID, username: TestHelper.username, sites: [site], passwordIndex: 0, lastPasswordTryIndex: 0, passwordOffset: nil, askToLogin: nil, askToChange: nil, enabled: false, version: 1)
        let backupAccount = BackupAccount(account: account, tokenURL: nil, tokenSecret: nil)
        let context = FakeLAContext()
        BackupManager.shared.backup(account: backupAccount) { (result) in
            XCTAssertTrue(result)
            do {
                let seed = try Keychain.shared.get(id: KeyIdentifier.backup.identifier(for: .seed), service: .seed)
                try BackupManager.shared.getBackupData(seed: seed, context: context) { (result) in
                    switch result {
                    case .success(let (total, failed)):
                        do {
                            XCTAssertEqual(total, 1)
                            XCTAssertEqual(failed, 0)
                            // GetBackupData automatically stores the account in the Keychain, so we verify if it is created correctly.
                            guard let account = try Account.get(accountID: TestHelper.userID, context: context) else {
                                return XCTFail("Account not found")
                            }
                            XCTAssertTrue(account.id == TestHelper.userID)
                            XCTAssertTrue(account.username == TestHelper.username)
                            expectation.fulfill()
                        } catch {
                            XCTFail(error.localizedDescription)
                            expectation.fulfill()
                        }
                    case .failure(let error):
                        XCTFail(error.localizedDescription)
                        expectation.fulfill()
                    }
                }
            } catch {
                XCTFail(error.localizedDescription)
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 3.0)
    }

    func testBackupAndGetBackupDataFailsIfAccountExists () {
        let expectation = XCTestExpectation(description: "Finish testBackupAndGetBackupDataFailsIfAccountExists")
        do {
            // Assure there currently no accounts in the Keychain
            Account.deleteAll()
            let site = TestHelper.sampleSite
            let account = Account(id: TestHelper.userID, username: TestHelper.username, sites: [site], passwordIndex: 0, lastPasswordTryIndex: 0, passwordOffset: nil, askToLogin: nil, askToChange: nil, enabled: false, version: 1)
            let data = try PropertyListEncoder().encode(account)
            try Keychain.shared.save(id: account.id, service: .account, secretData: "somepassword".data, objectData: data)
            let backupAccount = BackupAccount(account: account, tokenURL: nil, tokenSecret: nil)
            BackupManager.shared.backup(account: backupAccount) { (result) in
                XCTAssertTrue(result)
                do {
                    let seed = try Keychain.shared.get(id: KeyIdentifier.backup.identifier(for: .seed), service: .seed)
                    try BackupManager.shared.getBackupData(seed: seed, context: FakeLAContext()) { (result) in
                        switch result {
                        case .success(let (total, failed)):
                            XCTAssertEqual(total, 1)
                            XCTAssertEqual(failed, 1)
                            expectation.fulfill()
                        case .failure(let error):
                            XCTFail(error.localizedDescription)
                            expectation.fulfill()
                        }
                    }
                } catch {
                    XCTFail(error.localizedDescription)
                    expectation.fulfill()
                }
            }
        } catch {
            XCTFail(error.localizedDescription)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)
    }
}
