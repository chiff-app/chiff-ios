/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import XCTest

@testable import keyn

class SeedTests: XCTestCase {

    let context = FakeLAContext()
    let id = "ed98282a25e0ee58019d15523ad779bc27f2c84a73a3d43ae38acbeeede1988e"
    let data = "ZhOIrj7miy4fkGUtLE8-hMCcc9QHpvMqfvwUvS5qhwTzG-2DDq6tHWO17tKDNnNzE3XL-0HxWkAK8kXz__M_OYQ24Yci2hyBdW1xxTx1TDErSRokfkIbrneo6HIoHWoY7tmEfg8kOq3OY8iX3LkFxDAwW01_R_MCxS5xMhQLm_f_4XTsTmWP5mVZgPK8fc0MEW7u7YfGxZHuvHsseadb4gKrIHk7_Xtemg4bjLaxqh1POza_O7rZP2Q9wBKOLPMBp7MMOF41QQrdN-5MGVDnP7wJ3rKjnSLkhuSRxxVOGYUDyo-qLksoJ_D-TkO2zk8lDgnBQa43HPG9cbqNMW59dtsj4jE6JWaEU8zcqPGx54E5nzJzGrkGT1b9Q6llG4g8qfL-N1Cy_wmwGMHLdJfi0pFGcPURtsgs8Jbq4TbWEPwDavKvNHDJRaDYT-3umgJKR4CyYeovhWAuQphOeW7Zan6AtFEFI8nJXthiR90UN6CGPdOywrZhSIpC2yhwMhDQeViCM2S6FV_IpnT7D7CbkdVJko6DBuEpr3F2kw-CMPre5GRXsdaqXyY5bhqOWL074UrT3Y-HX3Uz7Zsc_3mMBUiP0ClrVScEHbeZ5VgtIJ9G-I1AwiW3fbxTYNXA0wE1Pxy5uvOtBqZ73R8Ow7fZOYMPEazNYDU-4CpGGMc1bP11BchC6MHPIjVMgwsiO5bpuNMTiAynTL8T5EGFXkHjAh-a0phSfM2B46hgwlRbFebQOlMz0isuaf4HxnxuRvdSnbAOnUFTIKuwPKYxF15qTj6qS7cluuVEHYde7HNeV_Ey70Jgd06ECkk59EqtmBV0gO0Y6rSeHWsQvAIZwmUkkgYCH4NTmpi4c6KkTyefRINeFSi_5Gah8-MCM7OD_OC3sdCuFBQBi6gSMcDEZg_khySRrFBSk1aUA2z7pEl9N0CLOrxQt-_7nRWxgiBZ7t1pxZ0yyQ7bVUhNdrdBdmoaaw-SNvOatOWDy0OCFQJvdKKrahPUwaEmc_P9cAnb-dznfQJHS8UCMiNvIUmx7UHPA_NvKq6gn9_9gUN00g"

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
        Seed.create(context: FakeLAContext()) { (result) in
            if case let .failure(error) = result {
                XCTFail(error.localizedDescription)
            }
        }
    }

    func testMnemonic() {
        Seed.mnemonic { (result) in
            switch result {
            case .success(let mnemonic):
                switch Locale.current.languageCode {
                case "nl":
                    XCTAssertEqual(["zucht", "vast", "lans", "troosten", "reclame", "gas", "geen", "blok", "falen", "jammer", "intiem", "kat"], mnemonic)
                default:
                    XCTAssertEqual(["wreck", "together", "kick", "tackle", "rely", "embrace", "enlist", "bright", "double", "happy", "group", "hope"], mnemonic)
                }

            case .failure(let error):
                XCTFail(error.localizedDescription)
            }
        }
    }

    func testMnemonicFailsIfNoData() {
        TestHelper.deleteLocalData()
        Seed.mnemonic { (result) in
            if case .success(_) = result {
                XCTFail("Should fail")
            }
        }
    }

    func testValidate() {
        XCTAssertTrue(Seed.validate(mnemonic: ["wreck", "together", "kick", "tackle", "rely", "embrace", "enlist", "bright", "double", "happy", "group", "hope"]))
        XCTAssertFalse(Seed.validate(mnemonic: ["Test"]))
    }

    func testRecover() {
        TestHelper.deleteLocalData()
        guard let pubKey = "Sv83e1XwETq4-buTc9fU29lHxCoRPlxA8Xr2pxnXQdI".fromBase64 else {
            return XCTFail("Error getting data from base64 seed")
        }
        API.shared = MockAPI(pubKey: pubKey.base64, account: [id: data])
        Seed.recover(context: context, mnemonic: ["wreck", "together", "kick", "tackle", "rely", "embrace", "enlist", "bright", "double", "happy", "group", "hope"]) { (result) in
            if case let .failure(error) = result {
                XCTFail(error.localizedDescription)
            }
        }
    }

    func testGetPasswordSeedDoesntThrow() {
        XCTAssertNoThrow(try Seed.getPasswordSeed(context: context))
    }

    func testGetPasswordThrowsIfNoData() {
        TestHelper.deleteLocalData()
        XCTAssertThrowsError(try Seed.getPasswordSeed(context: context))
    }

    func testGetPasswordSeed() {
        do {
            let passwordSeed = try Seed.getPasswordSeed(context: context)
            XCTAssertEqual(passwordSeed.base64, "L0y8UIj15Tl2jm2k5cZU8avW45GzOQi4kpHD-PdrAT0")
        } catch {
            XCTFail("Error getting password seed: \(error)")
        }
    }

    func testGetBackupSeedDoesntThrow() {
        XCTAssertNoThrow(try Seed.getBackupSeed(context: context))
    }

    func testGetBackupThrowsIfNoData() {
        TestHelper.deleteLocalData()
        XCTAssertThrowsError(try Seed.getBackupSeed(context: context))
    }

    func testGetBackupSeed() {
        do {
            let backupSeed = try Seed.getBackupSeed(context: context)
            XCTAssertEqual(backupSeed.base64, "bOqw6X0TH1Xp5jh9eX2KkoLX6wDsgqbFg5-E-cJhAYw")
        } catch {
            XCTFail("Error getting password seed: \(error)")
        }
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

    func testisBackedUp() {
        TestHelper.deleteLocalData()
        guard let pubKey = "Sv83e1XwETq4-buTc9fU29lHxCoRPlxA8Xr2pxnXQdI".fromBase64 else {
            return XCTFail("Error getting data from base64 seed")
        }
        API.shared = MockAPI(pubKey: pubKey.base64, account: [id: data])
        Seed.recover(context: context, mnemonic: ["wreck", "together", "kick", "tackle", "rely", "embrace", "enlist", "bright", "double", "happy", "group", "hope"]) { (result) in
            do {
                let _ = try result.get()
                guard let account = try Account.get(accountID: self.id, context: self.context) else {
                    return XCTFail("Account not found")
                }
                XCTAssertTrue(account.id == self.id)
            } catch {
                XCTFail(error.localizedDescription)
            }
        }
    }

    // MARK: - Integration Tests

    func testCreateAndMnemonicAndValidateAndDeleteAndRecover() {
        TestHelper.deleteLocalData()
        Seed.create(context: context) { (seedResult) in
            DispatchQueue.main.async {
                // If you do not call this code inside the main thread, keychain data may or may not be there
                // Usually ending up in no data and test will fail
                switch seedResult {
                case .success(_):
                    Seed.mnemonic { (result) in
                        do {
                            let mnemonic = try result.get()
                            XCTAssertTrue(Seed.validate(mnemonic: mnemonic))
                            try Seed.delete() // Calling this inside XCTAssertNoThrow only creates a warning, you need the catch anyways
                            Seed.recover(context: self.context, mnemonic: mnemonic, completionHandler: { (result) in
                                if case let .failure(error) = result {
                                    XCTFail(error.localizedDescription)
                                }
                            })
                        } catch {
                            XCTFail("Error deleting seeds \(error)")
                        }
                    }
                case .failure(let error): XCTFail(error.localizedDescription)
                }
            }
        }
    }
}
