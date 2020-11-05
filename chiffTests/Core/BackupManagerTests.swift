//
//  BackupManagerTests.swift
//  chiffTests
//
//  Copyright: see LICENSE.md
//

import XCTest
import LocalAuthentication
import PromiseKit

@testable import chiff

class SyncableTests: XCTestCase {

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
        TestHelper.createSeed()
    }

    override func tearDown() {
        super.tearDown()
        TestHelper.deleteLocalData()
    }

    // MARK: - Unit tests

    func testBackup() {
        let site = TestHelper.sampleSite
        let account = UserAccount(id: TestHelper.userID, username: TestHelper.username, sites: [site], passwordIndex: 0, lastPasswordTryIndex: 0, passwordOffset: nil, askToLogin: nil, askToChange: nil, version: 1, webAuthn: nil, notes: nil)
        XCTAssertNoThrow(try account.backup())
    }

    func testBackupFailsIfAPIFails() {
        let site = TestHelper.sampleSite
        let mockAPI = MockAPI(shouldFail: true)
        API.shared = mockAPI
        let account = UserAccount(id: TestHelper.userID, username: TestHelper.username, sites: [site], passwordIndex: 0, lastPasswordTryIndex: 0, passwordOffset: nil, askToLogin: nil, askToChange: nil, version: 1, webAuthn: nil, notes: nil)
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
            let account = UserAccount(id: TestHelper.userID, username: TestHelper.username, sites: [TestHelper.sampleSite], passwordIndex: 0, lastPasswordTryIndex: 0, passwordOffset: nil, askToLogin: nil, askToChange: nil, version: 1, webAuthn: nil, notes: nil)
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
            let account = UserAccount(id: TestHelper.userID, username: TestHelper.username, sites: [TestHelper.sampleSite], passwordIndex: 0, lastPasswordTryIndex: 0, passwordOffset: nil, askToLogin: nil, askToChange: nil, version: 1, webAuthn: nil, notes: nil)
            XCTAssertNoThrow(try account.deleteBackup())
            XCTAssertFalse(mockAPI.mockData[pubKey.base64]!.count < originalSize)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testGetBackupData() {
        let expectation = XCTestExpectation(description: "Finish testGetBackupData")
        do {
            guard let pubKey = try Keychain.shared.get(id: KeyIdentifier.pub.identifier(for: .backup), service: .backup) else {
                throw KeychainError.notFound
            }
            API.shared = MockAPI(pubKey: pubKey.base64, account: [TestHelper.userID: TestHelper.userData])
            UserAccount.restore(context: Self.context).catch { error in
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
            guard let pubKey = try Keychain.shared.get(id: KeyIdentifier.pub.identifier(for: .backup), service: .backup) else {
                throw KeychainError.notFound
            }
            API.shared = MockAPI(pubKey: pubKey.base64, account: [TestHelper.userID: TestHelper.userData], shouldFail: true)
            _ = UserAccount.restore(context: Self.context).done { _ in
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

    // MARK: - Integration tests

    func testBackupAndDeleteAccount() {
        let mockAPI = API.shared as! MockAPI
        let site = TestHelper.sampleSite
        let expectation = XCTestExpectation(description: "Finish testBackupAndDeleteAccount")
        let account = UserAccount(id: TestHelper.userID, username: TestHelper.username, sites: [site], passwordIndex: 0, lastPasswordTryIndex: 0, passwordOffset: nil, askToLogin: nil, askToChange: nil, version: 1, webAuthn: nil, notes: nil)
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
        let account = UserAccount(id: TestHelper.userID, username: TestHelper.username, sites: [site], passwordIndex: 0, lastPasswordTryIndex: 0, passwordOffset: nil, askToLogin: nil, askToChange: nil, version: 1, webAuthn: nil, notes: nil)
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
        let account = UserAccount(id: TestHelper.userID, username: TestHelper.username, sites: [site], passwordIndex: 0, lastPasswordTryIndex: 0, passwordOffset: nil, askToLogin: nil, askToChange: nil, version: 1, webAuthn: nil, notes: nil)
        do {
            let accountData = try PropertyListEncoder().encode(account)
            try Keychain.shared.save(id: account.id, service: .account, secretData: "somepassword".data, objectData: accountData)
            firstly {
                try account.backup()
            }.map { _ in
                try Keychain.shared.delete(id: account.id, service: .account)
            }.then { _ -> Promise<RecoveryResult>  in
                UserAccount.restore(context: Self.context)
            }.done { result in
                XCTAssertEqual(result.total, 1)
                XCTAssertEqual(result.failed, 0)
                // GetBackupData automatically stores the account in the Keychain, so we verify if it is created correctly.
                guard let account = try UserAccount.get(id: TestHelper.userID, context: Self.context) else {
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
            let account = UserAccount(id: TestHelper.userID, username: TestHelper.username, sites: [site], passwordIndex: 0, lastPasswordTryIndex: 0, passwordOffset: nil, askToLogin: nil, askToChange: nil, version: 1, webAuthn: nil, notes: nil)
            let data = try PropertyListEncoder().encode(account)
            try Keychain.shared.save(id: account.id, service: .account, secretData: "somepassword".data, objectData: data)
            firstly {
                try account.backup()
            }.then { (result) -> Promise<RecoveryResult>  in
                UserAccount.restore(context: Self.context)
            }.done { result in
                XCTAssertEqual(result.succeeded, 0)
                XCTAssertEqual(result.failed, 1)
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
