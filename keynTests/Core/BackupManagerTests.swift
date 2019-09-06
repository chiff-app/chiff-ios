/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import XCTest

@testable import keyn

class BackupManagerTests: XCTestCase {

    var context: FakeLAContext!
    let id = "ed98282a25e0ee58019d15523ad779bc27f2c84a73a3d43ae38acbeeede1988e"
    let username = "test@keyn.com"
    let data = "ZhOIrj7miy4fkGUtLE8-hMCcc9QHpvMqfvwUvS5qhwTzG-2DDq6tHWO17tKDNnNzE3XL-0HxWkAK8kXz__M_OYQ24Yci2hyBdW1xxTx1TDErSRokfkIbrneo6HIoHWoY7tmEfg8kOq3OY8iX3LkFxDAwW01_R_MCxS5xMhQLm_f_4XTsTmWP5mVZgPK8fc0MEW7u7YfGxZHuvHsseadb4gKrIHk7_Xtemg4bjLaxqh1POza_O7rZP2Q9wBKOLPMBp7MMOF41QQrdN-5MGVDnP7wJ3rKjnSLkhuSRxxVOGYUDyo-qLksoJ_D-TkO2zk8lDgnBQa43HPG9cbqNMW59dtsj4jE6JWaEU8zcqPGx54E5nzJzGrkGT1b9Q6llG4g8qfL-N1Cy_wmwGMHLdJfi0pFGcPURtsgs8Jbq4TbWEPwDavKvNHDJRaDYT-3umgJKR4CyYeovhWAuQphOeW7Zan6AtFEFI8nJXthiR90UN6CGPdOywrZhSIpC2yhwMhDQeViCM2S6FV_IpnT7D7CbkdVJko6DBuEpr3F2kw-CMPre5GRXsdaqXyY5bhqOWL074UrT3Y-HX3Uz7Zsc_3mMBUiP0ClrVScEHbeZ5VgtIJ9G-I1AwiW3fbxTYNXA0wE1Pxy5uvOtBqZ73R8Ow7fZOYMPEazNYDU-4CpGGMc1bP11BchC6MHPIjVMgwsiO5bpuNMTiAynTL8T5EGFXkHjAh-a0phSfM2B46hgwlRbFebQOlMz0isuaf4HxnxuRvdSnbAOnUFTIKuwPKYxF15qTj6qS7cluuVEHYde7HNeV_Ey70Jgd06ECkk59EqtmBV0gO0Y6rSeHWsQvAIZwmUkkgYCH4NTmpi4c6KkTyefRINeFSi_5Gah8-MCM7OD_OC3sdCuFBQBi6gSMcDEZg_khySRrFBSk1aUA2z7pEl9N0CLOrxQt-_7nRWxgiBZ7t1pxZ0yyQ7bVUhNdrdBdmoaaw-SNvOatOWDy0OCFQJvdKKrahPUwaEmc_P9cAnb-dznfQJHS8UCMiNvIUmx7UHPA_NvKq6gn9_9gUN00g"

    override func setUp() {
        super.setUp()
        TestHelper.createSeed()
        TestHelper.createBackupKeys()
        context = FakeLAContext()
        API.shared = MockAPI()
    }

    override func tearDown() {
        super.tearDown()
        TestHelper.deleteLocalData()
    }

    // MARK: - Unit tests

    func testBackup() {
        let site = TestHelper.sampleSite
        let account = Account(id: id, username: username, sites: [site], passwordIndex: 0, lastPasswordTryIndex: 0, passwordOffset: nil, askToLogin: nil, askToChange: nil, enabled: false, version: 1)
        let backupAccount = BackupAccount(account: account, tokenURL: nil, tokenSecret: nil)
        BackupManager.shared.backup(account: backupAccount) { (result) in
            XCTAssertTrue(result)
        }
    }

    func testDeleteAccount() {
        do {
            let pubKey = try Keychain.shared.get(id: KeyIdentifier.pub.identifier(for: .backup), service: .backup)
            let mockAPI = MockAPI(pubKey: pubKey.base64, account: [id: data])
            API.shared = mockAPI
            let originalSize = mockAPI.mockData[pubKey.base64]!.count
            try BackupManager.shared.deleteAccount(accountId: id)
            #warning("This is not the corrrect way I think, we should add a completionHandler to delete, so the test can fail based on that and most importantly the app should show that it wasn't possible to remove the account, deleteAllAccounts already does it")
            XCTAssertTrue(mockAPI.mockData[pubKey.base64]!.count < originalSize)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testDeleteAllAccounts() {
        do {
            let pubKey = try Keychain.shared.get(id: KeyIdentifier.pub.identifier(for: .backup), service: .backup)
            API.shared = MockAPI(pubKey: pubKey.base64, account: [id: data])
            BackupManager.shared.deleteAllAccounts(completionHandler: { (result) in
                switch result {
                case .success(_): XCTAssertTrue(true)
                case .failure(let error): XCTFail(error.localizedDescription)
                }
            })
        } catch {
            XCTFail("Failed getting pubKey")
        }
    }

    func testGetBackupData() {
        #warning("TODO: Perhaps we should add another tests that verifies if everything goes well in case the pubkey is not available in the Keychain.")
        do {
            let seed = try Keychain.shared.get(id: KeyIdentifier.backup.identifier(for: .seed), service: .seed)
            let pubKey = try Keychain.shared.get(id: KeyIdentifier.pub.identifier(for: .backup), service: .backup)
            API.shared = MockAPI(pubKey: pubKey.base64, account: [id: data])
            try BackupManager.shared.getBackupData(seed: seed, context: context) { (result) in
                if case let .failure(error) = result {
                    XCTFail(error.localizedDescription)
                }
            }
        } catch {
            XCTFail(error.localizedDescription)
        }
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
        let account = Account(id: id, username: username, sites: [site], passwordIndex: 0, lastPasswordTryIndex: 0, passwordOffset: nil, askToLogin: nil, askToChange: nil, enabled: false, version: 1)
        let backupAccount = BackupAccount(account: account, tokenURL: nil, tokenSecret: nil)
        BackupManager.shared.backup(account: backupAccount) { (result) in
            XCTAssertTrue(result)
            do {
                let pubKey = try Keychain.shared.get(id: KeyIdentifier.pub.identifier(for: .backup), service: .backup)
                let originalSize = mockAPI.mockData[pubKey.base64]!.count
                try BackupManager.shared.deleteAccount(accountId: self.id)
                XCTAssertTrue(mockAPI.mockData[pubKey.base64]!.count < originalSize)
            } catch {
                XCTFail(error.localizedDescription)
            }
        }
    }

    func testBackupAndDeleteAllAccounts() {
        let site = TestHelper.sampleSite
        let account = Account(id: id, username: username, sites: [site], passwordIndex: 0, lastPasswordTryIndex: 0, passwordOffset: nil, askToLogin: nil, askToChange: nil, enabled: false, version: 1)
        let backupAccount = BackupAccount(account: account, tokenURL: nil, tokenSecret: nil)
        BackupManager.shared.backup(account: backupAccount) { (result) in
            XCTAssertTrue(result)
            BackupManager.shared.deleteAllAccounts(completionHandler: { (result) in
                if case let .failure(error) = result {
                    XCTFail(error.localizedDescription)
                }
            })
        }
    }

    func testBackupAndGetBackupData() {
        // Assure there currently no accounts in the Keychain
        Account.deleteAll()
        let site = TestHelper.sampleSite
        let account = Account(id: id, username: username, sites: [site], passwordIndex: 0, lastPasswordTryIndex: 0, passwordOffset: nil, askToLogin: nil, askToChange: nil, enabled: false, version: 1)
        let backupAccount = BackupAccount(account: account, tokenURL: nil, tokenSecret: nil)
        BackupManager.shared.backup(account: backupAccount) { (result) in
            XCTAssertTrue(result)
            do {
                let seed = try Keychain.shared.get(id: KeyIdentifier.backup.identifier(for: .seed), service: .seed)
                try BackupManager.shared.getBackupData(seed: seed, context: self.context) { (result) in
                    switch result {
                    case .success(_):
                        do {
                            // GetBackupData automatically stores the account in the Keychain, so we verify if it is created correctly.
                            guard let account = try Account.get(accountID: self.id, context: self.context) else {
                                return XCTFail("Account not found")
                            }
                            XCTAssertTrue(account.id == self.id)
                            XCTAssertTrue(account.username == self.username)
                        } catch {
                            XCTFail(error.localizedDescription)
                        }
                    case .failure(let error): XCTFail(error.localizedDescription)
                    }
                }
            } catch {
                XCTFail(error.localizedDescription)
            }
        }
    }
}
