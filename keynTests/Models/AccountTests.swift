/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */

import XCTest
import OneTimePassword

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
        do {
            let account = try Account(username: TestHelper.username, sites: [TestHelper.sampleSite], passwordIndex: 0, password: nil, context: FakeLAContext())
            XCTAssertFalse(account.synced)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    func testInitDoesntThrow() {
        let context = FakeLAContext()
        XCTAssertNoThrow(try Account(username: TestHelper.username, sites: [TestHelper.sampleSite], passwordIndex: 0, password: nil, context: context))
        XCTAssertNoThrow(try Account(username: TestHelper.username + "2", sites: [TestHelper.sampleSite], passwordIndex: 0, password: "password", context: context))
    }
    
    func testNextPassword() {
        let site = TestHelper.sampleSite
        do {
            var account = try Account(username: TestHelper.username, sites: [site], passwordIndex: 0, password: nil, context: FakeLAContext())
            XCTAssertEqual(try account.nextPassword(), "[jh6eAX)og7A#nJ1:YDSrD6#61cf${\"A")
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testOneTimePasswordToken() {
        let site = TestHelper.sampleSite
        do {
            let account = try Account(username: TestHelper.username, sites: [site], passwordIndex: 0, password: nil, context: FakeLAContext())
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
    
    func testSetOtpDoesntThrow() {
        guard let token = Token(url: TestHelper.hotpURL) else {
            return XCTFail("Error creating token")
        }
        do {
            var account = try Account(username: TestHelper.username, sites: [TestHelper.sampleSite], passwordIndex: 0, password: nil, context: FakeLAContext())
            XCTAssertNoThrow(try account.setOtp(token: token))
            XCTAssertNoThrow(try account.setOtp(token: token)) // To call update instead of save
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    func testDeleteOtp() {
        do {
            var account = try Account(username: TestHelper.username, sites: [TestHelper.sampleSite], passwordIndex: 0, password: nil, context: FakeLAContext())
            TestHelper.saveHOTPToken(id: account.id)
            XCTAssertNoThrow(try account.deleteOtp())
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    func testAddSite() {
        do {
            var account = try Account(username: TestHelper.username, sites: [TestHelper.sampleSite], passwordIndex: 0, password: nil, context: FakeLAContext())
            XCTAssertNoThrow(try account.addSite(site: TestHelper.sampleSite))
            XCTAssertEqual(account.sites.count, 2)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    func testRemoveSite() {
        do {
            var account = try Account(username: TestHelper.username, sites: [TestHelper.sampleSite], passwordIndex: 0, password: nil, context: FakeLAContext())
            XCTAssertNoThrow(try account.removeSite(forIndex: 0))
            XCTAssertEqual(account.sites.count, 0)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    func testUpdateSite() {
        do {
            var account = try Account(username: TestHelper.username, sites: [TestHelper.sampleSite], passwordIndex: 0, password: nil, context: FakeLAContext())
            XCTAssertNoThrow(try account.updateSite(url: "google.com", forIndex: 0))
            XCTAssertEqual(account.sites.count, 1)
            XCTAssertEqual(account.sites[0].url, "google.com")
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    func testUpdate() {
        do {
            let siteName = "Google"
            let password = "testPassword"
            let url = "www.google.com"
            let context = FakeLAContext()
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
    
    func testUpdatePasswordAfterConfirmation() {
        let context = FakeLAContext()
        do {
            var account = try Account(username: TestHelper.username, sites: [TestHelper.sampleSite], passwordIndex: 0, password: nil, context: context)
            XCTAssertNoThrow(try account.updatePasswordAfterConfirmation(context: context))
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    func testDelete() {
        let context = FakeLAContext()
        TestHelper.createBackupKeys()
        let expectation = XCTestExpectation(description: "Finish testDelete")
        do {
            let account = try Account(username: TestHelper.username, sites: [TestHelper.sampleSite], passwordIndex: 0, password: nil, context: context)
            let accountId = account.id
            account.delete { (result) in
                do {
                    let _ = try result.get()
                    XCTAssertNil(try Account.get(accountID: accountId, context: context))
                    expectation.fulfill()
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
    
    func testDeleteWithoutBackupKeys() {
        let context = FakeLAContext()
        let expectation = XCTestExpectation(description: "Finish testDeleteWithoutBackupKeys")
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
        wait(for: [expectation], timeout: 3.0)
    }
    
    func testPassword() {
        let context = FakeLAContext()
        let expectation = XCTestExpectation(description: "Finish testPassword")
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
        wait(for: [expectation], timeout: 3.0)
    }
    
    func testAll() {
        let context = FakeLAContext()
        XCTAssertNoThrow(try Account.all(context: context))
        XCTAssertTrue(try Account.all(context: context).isEmpty)
        XCTAssertNoThrow(try Account(username: TestHelper.username, sites: [TestHelper.sampleSite], passwordIndex: 0, password: nil, context: context))
        XCTAssertNoThrow(try Account.all(context: context))
        XCTAssertFalse(try Account.all(context: context).isEmpty)
    }
    
    func testGetAccount() {
        XCTAssertNil(try Account.get(accountID: "noid", context: FakeLAContext()))
    }
    
    func testSave() {
        TestHelper.createBackupKeys()
        let context = FakeLAContext()
        guard let accountData = TestHelper.backupData.fromBase64 else {
            return XCTFail("Error converting to data")
        }
        XCTAssertNoThrow(try Account.save(accountData: accountData, id: TestHelper.userID, context: context))
        XCTAssertNotNil(try Account.get(accountID: TestHelper.userID, context: context))
    }
    
    func testAccountList() {
        let context = FakeLAContext()
        XCTAssertNoThrow(try Account.accountList(context: context))
        XCTAssertTrue(try Account.accountList(context: context).isEmpty)
    }

    func testDeleteAll() {
        let context = FakeLAContext()
        XCTAssertNoThrow(try Account(username: TestHelper.username, sites: [TestHelper.sampleSite], passwordIndex: 0, password: nil, context: context))
        XCTAssertNoThrow(try Account(username: TestHelper.username + "2", sites: [TestHelper.sampleSite], passwordIndex: 0, password: nil, context: context))
        Account.deleteAll()
        XCTAssertEqual(try Account.all(context: context).count, 0)
    }
    
    func testUpdateVersion() {
        let context = FakeLAContext()
        do {
            var account = try Account(username: TestHelper.username, sites: [TestHelper.sampleSite], passwordIndex: 0, password: nil, context: context)
            account.updateVersion(context: context)
            account.version = 0
            account.updateVersion(context: context)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    // MARK: - Integration Tests
    
    func testDeleteAndSyncAndGet() {
        TestHelper.createBackupKeys()
        let context = FakeLAContext()
        let expectation = XCTestExpectation(description: "Finish testDeleteAndSyncAndGet")
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
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)
    }

    func testUpdatePasswordAndConfirm() {
        let context = FakeLAContext()
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
    
    func testSetOtpAndDeleteOtp() {
        guard let token = Token(url: TestHelper.hotpURL) else {
            return XCTFail("Error creating token")
        }
        do {
            var account = try Account(username: TestHelper.username, sites: [TestHelper.sampleSite], passwordIndex: 0, password: nil, context: FakeLAContext())
            XCTAssertNoThrow(try account.setOtp(token: token))
            XCTAssertNoThrow(try account.deleteOtp())
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    func testAddSiteAndRemoveSite() {
        do {
            var account = try Account(username: TestHelper.username, sites: [TestHelper.sampleSite], passwordIndex: 0, password: nil, context: FakeLAContext())
            XCTAssertNoThrow(try account.addSite(site: TestHelper.sampleSite))
            XCTAssertEqual(account.sites.count, 2)
            XCTAssertNoThrow(try account.removeSite(forIndex: 0))
            XCTAssertEqual(account.sites.count, 1)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
}
