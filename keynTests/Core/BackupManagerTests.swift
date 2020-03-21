/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import XCTest
import LocalAuthentication
import PromiseKit

@testable import keyn

class BackupManagerTests: XCTestCase {

    var context: LAContext!

    override func setUp() {
        super.setUp()
        let exp = expectation(description: "Get an authenticated context")
        LocalAuthenticationManager.shared.authenticate(reason: "Testing", withMainContext: true).done { context in
            self.context = context
            TestHelper.createSeed()
            TestHelper.createBackupKeys()
        }.catch { error in
            fatalError("Failed to get context: \(error.localizedDescription)")
        }.finally {
            exp.fulfill()
        }
        waitForExpectations(timeout: 40, handler: nil)
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
            guard let backupSeed = try Keychain.shared.get(id: KeyIdentifier.backup.identifier(for: .seed), service: .seed) else {
                throw KeychainError.notFound
            }
            BackupManager.initialize(seed: backupSeed, context: nil).catch { error in
                XCTFail(error.localizedDescription)
            }.finally {
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
            guard let backupSeed = try Keychain.shared.get(id: KeyIdentifier.backup.identifier(for: .seed), service: .seed) else {
                throw KeychainError.notFound
            }
            BackupManager.initialize(seed: backupSeed, context: nil).ensure {
                expectation.fulfill()
            }.catch { error in
                XCTFail(error.localizedDescription)
            }.finally {
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
        BackupManager.initialize(seed: backupSeed, context: nil).done { (result) in
            XCTFail("Must fail")
        }.ensure {
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
            guard let backupSeed = try Keychain.shared.get(id: KeyIdentifier.backup.identifier(for: .seed), service: .seed) else {
                throw KeychainError.notFound
            }
            BackupManager.initialize(seed: backupSeed, context: nil).done { (result) in
                XCTFail("Must fail")
            }.ensure {
                expectation.fulfill()
            }
        } catch {
            XCTFail(error.localizedDescription)
        }
        wait(for: [expectation], timeout: 3.0)
    }
    
    func testBackup() {
        let site = TestHelper.sampleSite
        let account = UserAccount(id: TestHelper.userID, username: TestHelper.username, sites: [site], passwordIndex: 0, lastPasswordTryIndex: 0, passwordOffset: nil, askToLogin: nil, askToChange: nil, enabled: false, version: 1, webAuthn: nil)
        XCTAssertNoThrow(try account.backup())
    }
    
    func testBackupFailsIfAPIFails() {
        let site = TestHelper.sampleSite
        let mockAPI = MockAPI(shouldFail: true)
        API.shared = mockAPI
        let account = UserAccount(id: TestHelper.userID, username: TestHelper.username, sites: [site], passwordIndex: 0, lastPasswordTryIndex: 0, passwordOffset: nil, askToLogin: nil, askToChange: nil, enabled: false, version: 1, webAuthn: nil)
        XCTAssertNoThrow(try account.backup())
    }

    func testDeleteAccount() {
        do {
            guard let pubKey = try Keychain.shared.get(id: KeyIdentifier.pub.identifier(for: .backup), service: .backup) else {
                throw KeychainError.notFound
            }
            let mockAPI = MockAPI(pubKey: pubKey.base64, account: [TestHelper.userID: TestHelper.userData])
            API.shared = mockAPI
            let originalSize = mockAPI.mockData[pubKey.base64]!.count
            let account = UserAccount(id: TestHelper.userID, username: TestHelper.username, sites: [TestHelper.sampleSite], passwordIndex: 0, lastPasswordTryIndex: 0, passwordOffset: nil, askToLogin: nil, askToChange: nil, enabled: false, version: 1, webAuthn: nil)
            try account.deleteBackup()
            XCTAssertTrue(mockAPI.mockData[pubKey.base64]!.count < originalSize)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    func testDeleteAccountFailsIfAPIFails() {
        do {
            guard let pubKey = try Keychain.shared.get(id: KeyIdentifier.pub.identifier(for: .backup), service: .backup) else {
                throw KeychainError.notFound
            }
            let mockAPI = MockAPI(pubKey: pubKey.base64, account: [TestHelper.userID: TestHelper.userData], shouldFail: true)
            API.shared = mockAPI
            let originalSize = mockAPI.mockData[pubKey.base64]!.count
            let account = UserAccount(id: TestHelper.userID, username: TestHelper.username, sites: [TestHelper.sampleSite], passwordIndex: 0, lastPasswordTryIndex: 0, passwordOffset: nil, askToLogin: nil, askToChange: nil, enabled: false, version: 1, webAuthn: nil)
            XCTAssertNoThrow(try account.deleteBackup())
            XCTAssertFalse(mockAPI.mockData[pubKey.base64]!.count < originalSize)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testDeleteAllAccounts() {
        let expectation = XCTestExpectation(description: "Finish testDeleteAllAccounts")
        do {
            guard let pubKey = try Keychain.shared.get(id: KeyIdentifier.pub.identifier(for: .backup), service: .backup) else {
                throw KeychainError.notFound
            }
            API.shared = MockAPI(pubKey: pubKey.base64, account: [TestHelper.userID: TestHelper.userData])
            BackupManager.deleteBackupData().ensure {
                expectation.fulfill()
            }
        } catch {
            XCTFail("Failed getting pubKey")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)
    }
    
    func testDeleteAllAccountsFailsIfAPIFails() {
        let expectation = XCTestExpectation(description: "Finish testDeleteAllAccountsFailsIfAPIFails")
        do {
            guard let pubKey = try Keychain.shared.get(id: KeyIdentifier.pub.identifier(for: .backup), service: .backup) else {
                throw KeychainError.notFound
            }
            let mockAPI = MockAPI(pubKey: pubKey.base64, account: [TestHelper.userID: TestHelper.userData], shouldFail: true)
            API.shared = mockAPI
            BackupManager.deleteBackupData().done {
                XCTFail("Should fail")
            }.ensure {
                expectation.fulfill()
            }
        } catch {
            XCTFail("Failed getting pubKey")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)
    }
    
    func testDeleteAllAccountsFailsIfNoPrivateKey() {
        let expectation = XCTestExpectation(description: "Finish testDeleteAllAccountsFailsIfNoPrivateKey")
        do {
            guard let pubKey = try Keychain.shared.get(id: KeyIdentifier.pub.identifier(for: .backup), service: .backup) else {
                throw KeychainError.notFound
            }
            API.shared = MockAPI(pubKey: pubKey.base64, account: [TestHelper.userID: TestHelper.userData])
            TestHelper.deleteLocalData()
            BackupManager.deleteBackupData().done { result in
                XCTFail("Should fail")
            }.ensure {
                expectation.fulfill()
            }
        } catch {
            XCTFail("Failed getting pubKey")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)
    }

    func testGetBackupData() {
        let expectation = XCTestExpectation(description: "Finish testGetBackupData")
        do {
            guard let pubKey = try Keychain.shared.get(id: KeyIdentifier.pub.identifier(for: .backup), service: .backup), let seed = try Keychain.shared.get(id: KeyIdentifier.backup.identifier(for: .seed), service: .seed) else {
                throw KeychainError.notFound
            }
            API.shared = MockAPI(pubKey: pubKey.base64, account: [TestHelper.userID: TestHelper.userData])
            try BackupManager.getBackupData(seed: seed, context: context).catch { error in
                XCTFail(error.localizedDescription)
            }.finally {
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
            guard let pubKey = try Keychain.shared.get(id: KeyIdentifier.pub.identifier(for: .backup), service: .backup), let seed = try Keychain.shared.get(id: KeyIdentifier.backup.identifier(for: .seed), service: .seed) else {
                throw KeychainError.notFound
            }
            let mockAPI = MockAPI(pubKey: pubKey.base64, account: [TestHelper.userID: TestHelper.userData], shouldFail: true)
            API.shared = mockAPI
            try BackupManager.getBackupData(seed: seed, context: context).done { _ in
                XCTFail("Should fail")
            }.ensure {
                expectation.fulfill()
            }
        } catch {
            XCTFail(error.localizedDescription)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testGetBackupDataIfNoPubKey() {
        TestHelper.deleteLocalData()
        TestHelper.createSeed()
        let expectation = XCTestExpectation(description: "Finish testGetBackupDataIfNoPubKey")
        do {
            guard let seed = try Keychain.shared.get(id: KeyIdentifier.backup.identifier(for: .seed), service: .seed) else {
                throw KeychainError.notFound
            }
            try BackupManager.getBackupData(seed: seed, context: context).ensure {
                expectation.fulfill()
            }.catch { error in
                XCTFail(error.localizedDescription)
            }
        } catch {
            XCTFail(error.localizedDescription)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)
    }

    func testPublicKeyDoesntThrow() {
        XCTAssertNoThrow(try BackupManager.publicKey())
    }

    func testPublicKey() {
        do {
            let publicKey = try BackupManager.publicKey()
            XCTAssertEqual(publicKey, "Sv83e1XwETq4-buTc9fU29lHxCoRPlxA8Xr2pxnXQdI")
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testPrivateKeyDoesntThrow() {
        XCTAssertNoThrow(try BackupManager.privateKey())
    }
    
    func testPrivateKeyThrows() {
        TestHelper.deleteLocalData()
        XCTAssertThrowsError(try BackupManager.privateKey())
    }

    func testPrivateKey() {
        do {
            let privateKey = try BackupManager.privateKey()
            guard let constantKey = TestHelper.backupPrivKey.fromBase64 else {
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
        let account = UserAccount(id: TestHelper.userID, username: TestHelper.username, sites: [site], passwordIndex: 0, lastPasswordTryIndex: 0, passwordOffset: nil, askToLogin: nil, askToChange: nil, enabled: false, version: 1, webAuthn: nil)
        do {
            let accountData = try PropertyListEncoder().encode(account)
            try Keychain.shared.save(id: account.id, service: .account, secretData: "somepassword".data, objectData: accountData)
            firstly {
                try account.backup()
            }.done { _ in
                guard let pubKey = try Keychain.shared.get(id: KeyIdentifier.pub.identifier(for: .backup), service: .backup) else {
                    throw KeychainError.notFound
                }
                let originalSize = mockAPI.mockData[pubKey.base64]!.count
                try account.deleteBackup()
                XCTAssertTrue(mockAPI.mockData[pubKey.base64]!.count < originalSize)
            }.catch { error in
                XCTFail("Error: \(error)")
            }.finally {
                expectation.fulfill()
            }
        } catch {
            XCTFail("Error: \(error)")
        }
        wait(for: [expectation], timeout: 3.0)
    }

    func testBackupAndDeleteAllAccounts() {
        let site = TestHelper.sampleSite
        let expectation = XCTestExpectation(description: "Finish testBackupAndDeleteAllAccounts")
        let account = UserAccount(id: TestHelper.userID, username: TestHelper.username, sites: [site], passwordIndex: 0, lastPasswordTryIndex: 0, passwordOffset: nil, askToLogin: nil, askToChange: nil, enabled: false, version: 1, webAuthn: nil)
        do {
            let accountData = try PropertyListEncoder().encode(account)
            try Keychain.shared.save(id: account.id, service: .account, secretData: "somepassword".data, objectData: accountData)
            firstly {
                try account.backup()
            }.done { _ in
                try account.deleteBackup()
            }.catch { error in
                XCTFail("Error: \(error)")
            }.finally {
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 3.0)
        } catch {
            XCTFail("Error: \(error)")
        }
    }

       func testBackupAndGetBackupData() {
        // Assure there currently no accounts in the Keychain
        UserAccount.deleteAll()
        let site = TestHelper.sampleSite
        let expectation = XCTestExpectation(description: "Finish testBackupAndGetBackupData")
        let account = UserAccount(id: TestHelper.userID, username: TestHelper.username, sites: [site], passwordIndex: 0, lastPasswordTryIndex: 0, passwordOffset: nil, askToLogin: nil, askToChange: nil, enabled: false, version: 1, webAuthn: nil)
        do {
            let accountData = try PropertyListEncoder().encode(account)
            try Keychain.shared.save(id: account.id, service: .account, secretData: "somepassword".data, objectData: accountData)
            firstly {
                try account.backup()
            }.map { _ in
                try Keychain.shared.delete(id: account.id, service: .account)
            }.then { _ -> Promise<(Int,Int,Int,Int)>  in
                guard let seed = try Keychain.shared.get(id: KeyIdentifier.backup.identifier(for: .seed), service: .seed) else {
                    throw KeychainError.notFound
                }
                return try BackupManager.getBackupData(seed: seed, context: self.context)
            }.done { (total, failed, _, _) in
                XCTAssertEqual(total, 1)
                XCTAssertEqual(failed, 0)
                // GetBackupData automatically stores the account in the Keychain, so we verify if it is created correctly.
                guard let account = try UserAccount.get(accountID: TestHelper.userID, context: self.context) else {
                    return XCTFail("Account not found")
                }
                XCTAssertTrue(account.id == TestHelper.userID)
                XCTAssertTrue(account.username == TestHelper.username)
            }.catch { error in
                XCTFail("Error: \(error)")
            }.finally {
                expectation.fulfill()
            }
        } catch {
            XCTFail("Error: \(error)")
        }

        wait(for: [expectation], timeout: 300.0)
    }

    func testBackupAndGetBackupDataFailsIfAccountExists () {
        let expectation = XCTestExpectation(description: "Finish testBackupAndGetBackupDataFailsIfAccountExists")
        do {
            // Assure there currently no accounts in the Keychain
            UserAccount.deleteAll()
            let site = TestHelper.sampleSite
            let account = UserAccount(id: TestHelper.userID, username: TestHelper.username, sites: [site], passwordIndex: 0, lastPasswordTryIndex: 0, passwordOffset: nil, askToLogin: nil, askToChange: nil, enabled: false, version: 1, webAuthn: nil)
            let data = try PropertyListEncoder().encode(account)
            try Keychain.shared.save(id: account.id, service: .account, secretData: "somepassword".data, objectData: data)
            firstly {
                try account.backup()
            }.then { (result) -> Promise<(Int,Int,Int,Int)>  in
                guard let seed = try Keychain.shared.get(id: KeyIdentifier.backup.identifier(for: .seed), service: .seed) else {
                    throw KeychainError.notFound
                }
                return try BackupManager.getBackupData(seed: seed, context: self.context)
            }.done { (succeeded, failed, _, _) in
                XCTAssertEqual(succeeded, 1)
                XCTAssertEqual(failed, 1)
            }.catch { error in
                XCTFail(error.localizedDescription)
            }.finally {
                expectation.fulfill()
            }
        } catch {
            XCTFail(error.localizedDescription)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)
    }
}
