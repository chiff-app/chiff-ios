/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */

import XCTest
import OneTimePassword
import LocalAuthentication

@testable import keyn
import AuthenticationServices

class AccountTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        TestHelper.createSeed()
    }
    
    override func tearDown() {
        super.tearDown()
        TestHelper.deleteLocalData()
    }
    
    // MARK: - Unit tests
    
    func testSynced() {
        let expectation = XCTestExpectation(description: "Finish testSynced")
        LocalAuthenticationManager.shared.authenticate(reason: "Testing", withMainContext: true) { (result) in
            switch result {
            case .failure(let error): XCTFail(error.localizedDescription)
            case .success(let context):
                do {
                    let account = try Account(username: TestHelper.username, sites: [TestHelper.sampleSite], passwordIndex: 0, password: nil, context: context)
                    XCTAssertFalse(account.synced)
                } catch {
                    XCTFail(error.localizedDescription)
                }
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testInitDoesntThrow() {
        let expectation = XCTestExpectation(description: "Finish testInitDoesntThrow")
        LocalAuthenticationManager.shared.authenticate(reason: "Testing", withMainContext: true) { (result) in
            switch result {
            case .failure(let error): XCTFail(error.localizedDescription)
            case .success(let context):
                do {
                    XCTAssertNoThrow(try Account(username: TestHelper.username, sites: [TestHelper.sampleSite], passwordIndex: 0, password: nil, context: context))
                    XCTAssertNoThrow(try Account(username: TestHelper.username + "2", sites: [TestHelper.sampleSite], passwordIndex: 0, password: "password", context: context))
                } catch {
                    XCTFail(error.localizedDescription)
                }
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testNextPassword() {
        let site = TestHelper.sampleSite
        let expectation = XCTestExpectation(description: "Finish testNextPassword")
        LocalAuthenticationManager.shared.authenticate(reason: "Testing", withMainContext: true) { (result) in
            switch result {
            case .failure(let error): XCTFail(error.localizedDescription)
            case .success(let context):
                do {
                    var account = try Account(username: TestHelper.username, sites: [site], passwordIndex: 0, password: nil, context: context)
                    XCTAssertEqual(try account.nextPassword(), "[jh6eAX)og7A#nJ1:YDSrD6#61cf${\"A")
                } catch {
                    XCTFail(error.localizedDescription)
                }
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10.0)
    }

    func testOneTimePasswordToken() {
        let site = TestHelper.sampleSite
        let expectation = XCTestExpectation(description: "Finish testOneTimePasswordToken")
        LocalAuthenticationManager.shared.authenticate(reason: "Testing", withMainContext: true) { (result) in
            switch result {
            case .failure(let error): XCTFail(error.localizedDescription)
            case .success(let context):
                do {
                    let account = try Account(username: TestHelper.username, sites: [site], passwordIndex: 0, password: nil, context: context)
                    TestHelper.saveHOTPToken(id: account.id)
                    let token = try account.oneTimePasswordToken()
                    XCTAssertNotNil(token)
                    XCTAssertEqual(token!.currentPassword!, "780815")                   // First HOTP password
                    XCTAssertEqual(token!.updatedToken().currentPassword!, "405714")    // Second HOTP password
                    TestHelper.deleteLocalData()
                    TestHelper.saveHOTPToken(id: account.id, includeData: false)
                    XCTAssertThrowsError(try account.oneTimePasswordToken())
                } catch {
                    XCTFail(error.localizedDescription)
                }
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testSetOtpDoesntThrow() {
        guard let token = Token(url: TestHelper.hotpURL) else {
            return XCTFail("Error creating token")
        }
        let expectation = XCTestExpectation(description: "Finish testSetOtpDoesntThrow")
        LocalAuthenticationManager.shared.authenticate(reason: "Testing", withMainContext: true) { (result) in
            switch result {
            case .failure(let error): XCTFail(error.localizedDescription)
            case .success(let context):
                do {
                    var account = try Account(username: TestHelper.username, sites: [TestHelper.sampleSite], passwordIndex: 0, password: nil, context: context)
                    XCTAssertNoThrow(try account.setOtp(token: token))
                    XCTAssertNoThrow(try account.setOtp(token: token)) // To call update instead of save
                } catch {
                    XCTFail(error.localizedDescription)
                }
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testDeleteOtp() {
        let expectation = XCTestExpectation(description: "Finish testDeleteOtp")
        LocalAuthenticationManager.shared.authenticate(reason: "Testing", withMainContext: true) { (result) in
            switch result {
            case .failure(let error): XCTFail(error.localizedDescription)
            case .success(let context):
                do {
                    var account = try Account(username: TestHelper.username, sites: [TestHelper.sampleSite], passwordIndex: 0, password: nil, context: context)
                    TestHelper.saveHOTPToken(id: account.id)
                    XCTAssertNoThrow(try account.deleteOtp())
                } catch {
                    XCTFail(error.localizedDescription)
                }
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testAddSite() {
        let expectation = XCTestExpectation(description: "Finish testAddSite")
        LocalAuthenticationManager.shared.authenticate(reason: "Testing", withMainContext: true) { (result) in
            switch result {
            case .failure(let error): XCTFail(error.localizedDescription)
            case .success(let context):
                do {
                    var account = try Account(username: TestHelper.username, sites: [TestHelper.sampleSite], passwordIndex: 0, password: nil, context: context)
                    XCTAssertNoThrow(try account.addSite(site: TestHelper.sampleSite))
                    XCTAssertEqual(account.sites.count, 2)
                } catch {
                    XCTFail(error.localizedDescription)
                }
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testRemoveSite() {
        let expectation = XCTestExpectation(description: "Finish testRemoveSite")
        LocalAuthenticationManager.shared.authenticate(reason: "Testing", withMainContext: true) { (result) in
            switch result {
            case .failure(let error): XCTFail(error.localizedDescription)
            case .success(let context):
                do {
                    var account = try Account(username: TestHelper.username, sites: [TestHelper.sampleSite], passwordIndex: 0, password: nil, context: context)
                    XCTAssertNoThrow(try account.removeSite(forIndex: 0))
                    XCTAssertEqual(account.sites.count, 0)
                } catch {
                    XCTFail(error.localizedDescription)
                }
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testUpdateSite() {
        let expectation = XCTestExpectation(description: "Finish testUpdateSite")
        LocalAuthenticationManager.shared.authenticate(reason: "Testing", withMainContext: true) { (result) in
            switch result {
            case .failure(let error): XCTFail(error.localizedDescription)
            case .success(let context):
                do {
                    var account = try Account(username: TestHelper.username, sites: [TestHelper.sampleSite], passwordIndex: 0, password: nil, context: context)
                    XCTAssertNoThrow(try account.updateSite(url: "google.com", forIndex: 0))
                    XCTAssertEqual(account.sites.count, 1)
                    XCTAssertEqual(account.sites[0].url, "google.com")
                } catch {
                    XCTFail(error.localizedDescription)
                }
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testUpdate() {
        let expectation = XCTestExpectation(description: "Finish testUpdate")
        LocalAuthenticationManager.shared.authenticate(reason: "Testing", withMainContext: true) { (result) in
            switch result {
            case .failure(let error): XCTFail(error.localizedDescription)
            case .success(let context):
                do {
                    let siteName = "Google"
                    let password = "testPassword"
                    let url = "www.google.com"
                    var account = try Account(username: TestHelper.username, sites: [TestHelper.sampleSite], passwordIndex: 0, password: nil, context: context)
                    XCTAssertNoThrow(try account.update(username: TestHelper.username, password: password, siteName: siteName, url: url, askToLogin: true, askToChange: false, enabled: true, context: context))
                    XCTAssertNoThrow(try account.update(username: TestHelper.username, password: password, siteName: siteName, url: url, askToLogin: true, askToChange: nil, enabled: true, context: context))
                    XCTAssertNoThrow(try account.update(username: TestHelper.username, password: nil, siteName: siteName, url: url, askToLogin: true, askToChange: nil, enabled: true, context: context))
                    XCTAssertEqual(account.username, TestHelper.username)
                    XCTAssertEqual(try account.password(), password)
                    XCTAssertEqual(account.site.name, siteName)
                    XCTAssertEqual(account.site.url, url)
                } catch {
                    XCTFail(error.localizedDescription)
                }
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testUpdatePasswordAfterConfirmation() {
        let expectation = XCTestExpectation(description: "Finish testUpdatePasswordAfterConfirmation")
        LocalAuthenticationManager.shared.authenticate(reason: "Testing", withMainContext: true) { (result) in
            switch result {
            case .failure(let error): XCTFail(error.localizedDescription)
            case .success(let context):
                do {
                    var account = try Account(username: TestHelper.username, sites: [TestHelper.sampleSite], passwordIndex: 0, password: nil, context: context)
                    XCTAssertNoThrow(try account.updatePasswordAfterConfirmation(context: context))
                } catch {
                    XCTFail(error.localizedDescription)
                }
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testDelete() {
        TestHelper.createBackupKeys()
        let expectation = XCTestExpectation(description: "Finish testDelete")
        LocalAuthenticationManager.shared.authenticate(reason: "Testing", withMainContext: true) { (result) in
            switch result {
            case .failure(let error):
                XCTFail(error.localizedDescription)
                expectation.fulfill()
            case .success(let context):
                do {
                    let account = try Account(username: TestHelper.username, sites: [TestHelper.sampleSite], passwordIndex: 0, password: nil, context: context)
                    let accountId = account.id
                    account.delete { (result) in
                        do {
                            let _ = try result.get()
                            XCTAssertNil(try Account.get(accountID: accountId, context: context))
                        } catch {
                            XCTFail(error.localizedDescription)
                        }
                        expectation.fulfill()
                    }
                } catch {
                    XCTFail(error.localizedDescription)
                    expectation.fulfill()
                }
            }
        }
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testDeleteWithoutBackupKeys() {
        let expectation = XCTestExpectation(description: "Finish testDeleteWithoutBackupKeys")
        LocalAuthenticationManager.shared.authenticate(reason: "Testing", withMainContext: true) { (result) in
            switch result {
            case .failure(let error):
                XCTFail(error.localizedDescription)
                expectation.fulfill()
            case .success(let context):
                do {
                    let account = try Account(username: TestHelper.username, sites: [TestHelper.sampleSite], passwordIndex: 0, password: nil, context: context)
                    account.delete { (result) in
                        if case .success(_) = result {
                            XCTFail("Should fail")
                        }
                        expectation.fulfill()
                    }
                } catch {
                    XCTFail(error.localizedDescription)
                    expectation.fulfill()
                }
            }
        }
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testPassword() {
        let expectation = XCTestExpectation(description: "Finish testPassword")
        LocalAuthenticationManager.shared.authenticate(reason: "Testing", withMainContext: true) { (result) in
            switch result {
            case .failure(let error):
                XCTFail(error.localizedDescription)
                expectation.fulfill()
            case .success(let context):
                do {
                    let account = try Account(username: TestHelper.username, sites: [TestHelper.sampleSite], passwordIndex: 0, password: nil, context: context)
                    account.password(reason: "Testing", context: context, type: .ifNeeded) { (result) in
                        switch result {
                        case .failure(let error): XCTFail(error.localizedDescription)
                        case .success(let password): XCTAssertEqual(password, "vGx$85gzsLZ/eK23ngx[afwG^0?#y%]C")
                        }
                        expectation.fulfill()
                    }
                } catch {
                    XCTFail(error.localizedDescription)
                    expectation.fulfill()
                }
            }
        }
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testAll() {
        let expectation = XCTestExpectation(description: "Finish testAll")
        LocalAuthenticationManager.shared.authenticate(reason: "Testing", withMainContext: true) { (result) in
            switch result {
            case .failure(let error): XCTFail(error.localizedDescription)
            case .success(let context):
                do {
                    XCTAssertNoThrow(try Account.all(context: context))
                    XCTAssertTrue(try Account.all(context: context).isEmpty)
                    XCTAssertNoThrow(try Account(username: TestHelper.username, sites: [TestHelper.sampleSite], passwordIndex: 0, password: nil, context: context))
                    XCTAssertNoThrow(try Account.all(context: context))
                    XCTAssertFalse(try Account.all(context: context).isEmpty)
                } catch {
                    XCTFail(error.localizedDescription)
                }
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testGetAccount() {
        XCTAssertNil(try Account.get(accountID: "noid", context: nil))
    }
    
    func testSave() {
        TestHelper.createBackupKeys()
        guard let accountData = TestHelper.backupData.fromBase64 else {
            return XCTFail("Error converting to data")
        }
        let expectation = XCTestExpectation(description: "Finish testSave")
        LocalAuthenticationManager.shared.authenticate(reason: "Testing", withMainContext: true) { (result) in
            switch result {
            case .failure(let error): XCTFail(error.localizedDescription)
            case .success(let context):
                do {
                    XCTAssertNoThrow(try Account.save(accountData: accountData, id: TestHelper.userID, context: context))
                    XCTAssertNotNil(try Account.get(accountID: TestHelper.userID, context: context))
                } catch {
                    XCTFail(error.localizedDescription)
                }
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testAccountList() {
        XCTAssertNoThrow(try Account.accountList())
        XCTAssertTrue(try Account.accountList().isEmpty)
    }

    func testDeleteAll() {
        let expectation = XCTestExpectation(description: "Finish testDeleteAll")
        LocalAuthenticationManager.shared.authenticate(reason: "Testing", withMainContext: true) { (result) in
            switch result {
            case .failure(let error): XCTFail(error.localizedDescription)
            case .success(let context):
                do {
                    XCTAssertNoThrow(try Account(username: TestHelper.username, sites: [TestHelper.sampleSite], passwordIndex: 0, password: nil, context: context))
                    XCTAssertNoThrow(try Account(username: TestHelper.username + "2", sites: [TestHelper.sampleSite], passwordIndex: 0, password: nil, context: context))
                    Account.deleteAll()
                    XCTAssertEqual(try Account.all(context: context).count, 0)
                } catch {
                    XCTFail(error.localizedDescription)
                }
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testUpdateVersion() {
        let expectation = XCTestExpectation(description: "Finish testUpdateVersion")
        LocalAuthenticationManager.shared.authenticate(reason: "Testing", withMainContext: true) { (result) in
            switch result {
            case .failure(let error): XCTFail(error.localizedDescription)
            case .success(let context):
                do {
                    var account = try Account(username: TestHelper.username, sites: [TestHelper.sampleSite], passwordIndex: 0, password: nil, context: context)
                    account.updateVersion(context: context)
                    account.version = 0
                    account.updateVersion(context: context)
                } catch {
                    XCTFail(error.localizedDescription)
                }
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10.0)
    }
    
    // MARK: - Integration Tests
    
    func testDeleteAndSyncAndGet() {
        TestHelper.createBackupKeys()
        let expectation = XCTestExpectation(description: "Finish testDeleteAndSyncAndGet")
        LocalAuthenticationManager.shared.authenticate(reason: "Testing", withMainContext: true) { (result) in
            switch result {
            case .failure(let error): XCTFail(error.localizedDescription)
            case .success(let context):
                do {
                    let account = try Account(username: TestHelper.username, sites: [TestHelper.sampleSite], passwordIndex: 0, password: nil, context: context)
                    let accountId = account.id
                    account.delete { (result) in
                        do {
                            try result.get()
                            XCTAssertTrue(account.synced)
                            XCTAssertNil(try Account.get(accountID: accountId, context: context))
                            expectation.fulfill()
                        } catch {
                            XCTFail(error.localizedDescription)
                            expectation.fulfill()
                        }
                    }
                } catch {
                    XCTFail(error.localizedDescription)
                }
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10.0)
    }

    func testUpdatePasswordAndConfirm() {
        let expectation = XCTestExpectation(description: "Finish testUpdatePasswordAndConfirm")
        LocalAuthenticationManager.shared.authenticate(reason: "Testing", withMainContext: true) { (result) in
            switch result {
            case .failure(let error): XCTFail(error.localizedDescription)
            case .success(let context):
                do {
                    var account = try Account(username: TestHelper.username, sites: [TestHelper.sampleSite], passwordIndex: 0, password: nil, context: context)
                    let newPassword = try account.nextPassword()
                    XCTAssertNotEqual(newPassword, try account.password())
                    XCTAssertNoThrow(try account.updatePasswordAfterConfirmation(context: context))
                    XCTAssertEqual(newPassword, try account.password())
                } catch {
                    XCTFail(error.localizedDescription)
                }
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testSetOtpAndDeleteOtp() {
        guard let token = Token(url: TestHelper.hotpURL) else {
            return XCTFail("Error creating token")
        }
        let expectation = XCTestExpectation(description: "Finish testUpdatePasswordAndConfirm")
        LocalAuthenticationManager.shared.authenticate(reason: "Testing", withMainContext: true) { (result) in
            switch result {
            case .failure(let error): XCTFail(error.localizedDescription)
            case .success(let context):
                do {
                    var account = try Account(username: TestHelper.username, sites: [TestHelper.sampleSite], passwordIndex: 0, password: nil, context: context)
                    XCTAssertNoThrow(try account.setOtp(token: token))
                    XCTAssertNoThrow(try account.deleteOtp())
                } catch {
                    XCTFail(error.localizedDescription)
                }
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testAddSiteAndRemoveSite() {
        let expectation = XCTestExpectation(description: "Finish testUpdatePasswordAndConfirm")
        LocalAuthenticationManager.shared.authenticate(reason: "Testing", withMainContext: true) { (result) in
            switch result {
            case .failure(let error): XCTFail(error.localizedDescription)
            case .success(let context):
                do {
                    var account = try Account(username: TestHelper.username, sites: [TestHelper.sampleSite], passwordIndex: 0, password: nil, context: context)
                    XCTAssertNoThrow(try account.addSite(site: TestHelper.sampleSite))
                    XCTAssertEqual(account.sites.count, 2)
                    XCTAssertNoThrow(try account.removeSite(forIndex: 0))
                    XCTAssertEqual(account.sites.count, 1)
                } catch {
                    XCTFail(error.localizedDescription)
                }
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10.0)
    }
}
