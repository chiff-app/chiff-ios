/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import XCTest
import LocalAuthentication

@testable import keyn

class FakeLAContext: LAContext {
    override func evaluatePolicy(_ policy: LAPolicy, localizedReason: String, reply: @escaping (Bool, Error?) -> Void) {
        reply(true, nil)
    }
    override func canEvaluatePolicy(_ policy: LAPolicy, error: NSErrorPointer) -> Bool {
        return true
    }
}

class BackupManagerTests: XCTestCase {

    var context: FakeLAContext!
    let id = "ed98282a25e0ee58019d15523ad779bc27f2c84a73a3d43ae38acbeeede1988e"
    let username = "test@keyn.com"
    let data = "5JHVmG4Y4vpikE3qio-ldfj6QRkPi0U-rxCv1xV6KqA97950SMEUhL50C1ehZJ1Le2bojvjYyRiv2EyKyuOe9dAA0SH03r8TdHcIAkKSYWe_A6YCi6-hVSaVLLWB5osohVrAOYNJNFklV4G6zBdzSL331vyL5Dc3Y4vtN_vbICRmbGC3Y-l6cp89QOMID9syjYGo0Kdql8swHtD9jslgRQZiLYsI-hjbblzHufKwX17c5fyWOthYg5-axuxCE29BH9aSXnZ_iV9NhSdIqx1dFu4LGjN6_9mmTXtLlFbLX-NzYwiVsKepTli1hLPuT02qWUH7-HNJn_EUmFKfqimT-ThV8Rx3bR_FnuJ70r8lnpw8uo6UM0oW9_B_LEWSQzpgpBsw4NVVafO4lJ5nslc2NKDLr8d7zUF5341VlIwn0xeS96wF3utSTJFj5uvlREMEoz0nRKus2SRErOm8M-KEHGB0UTPEskGZTHFBNjkqzdWG7t61Xle1RcbTLBDwLGFWvQUrQbuPCn9yTTFo5U53y9joVfLh5ybsvvxZLLywCBylT7KoMWGWiLoT_rJpBEtpQjPo0KdQinsYSryUV0KrfuPSvDpI9hsNppgpdGoi1Ipz8WMmbDlxejueF_yF3CgIlAXt611yBeIRioOz6KbDzfDKJULMI1qJcNXsEQFJoGMwRa-viaSOe1SGMrt4tc8Av75u6rdZlR_3lhC-EWINWaUePsrEMTFA1JJKlZUDpiLzVGfB6VjATNEB4TyKPTT3GzTAws8B1Vj2oarHArLW6x2_Vl2oOCJB9Co-RvqHBBiWexUYhdVNkfPp9qhgpKbn1tqGiQiVSwnNwA1KLCgF2K-WTCTUFPGcNwchqs9Re6aSOF-LYFEW03MuA9ChpaqQoWs35qGaUUKdPgKeTg3h1DEFJgJ889dI5MswFf0edfis8wEKxExV7ZcT-9vFmRgNQBEzFQ0DgxOFBx2rnQuZHnXXGga8y0Nb5yPEpd_8jZfB0EjN-A61-uNABJBPJbAKj5CYDZthwUzLc1XBdddzVDn33FSVrR6g98nKxA"

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
        do {
            let seed = try Keychain.shared.get(id: KeyIdentifier.backup.identifier(for: .seed), service: .seed)
            let pubKey = try Keychain.shared.get(id: KeyIdentifier.pub.identifier(for: .backup), service: .backup)
            API.shared = MockAPI(pubKey: pubKey.base64, account: [id: data])
            try BackupManager.shared.getBackupData(seed: seed, context: context) { (result) in
                switch result {
                case .success(_): XCTAssertTrue(true)
                case .failure(let error): XCTFail(error.localizedDescription)
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
            print(privateKey.base64)
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
            do {
                BackupManager.shared.deleteAllAccounts(completionHandler: { (result) in
                    switch result {
                    case .success(_): XCTAssertTrue(true)
                    case .failure(let error): XCTFail(error.localizedDescription)
                    }
                })
            } catch {
                XCTFail(error.localizedDescription)
            }
        }
    }

    func testBackupAndGetBackupData() {
        let site = TestHelper.sampleSite
        let account = Account(id: id, username: username, sites: [site], passwordIndex: 0, lastPasswordTryIndex: 0, passwordOffset: nil, askToLogin: nil, askToChange: nil, enabled: false, version: 1)
        let backupAccount = BackupAccount(account: account, tokenURL: nil, tokenSecret: nil)
        BackupManager.shared.backup(account: backupAccount) { (result) in
            XCTAssertTrue(result)
            do {
                let seed = try Keychain.shared.get(id: KeyIdentifier.backup.identifier(for: .seed), service: .seed)
                try BackupManager.shared.getBackupData(seed: seed, context: self.context) { (result) in
                    switch result {
                    case .success(_): XCTAssertTrue(true)
                    case .failure(let error): XCTFail(error.localizedDescription)
                    }
                }
            } catch {
                XCTFail(error.localizedDescription)
            }
        }
    }
}
