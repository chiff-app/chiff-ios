/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */

import XCTest
import OneTimePassword
import LocalAuthentication

@testable import keyn
import AuthenticationServices
import PromiseKit

class AccountTests: XCTestCase {

    override static func setUp() {
        super.setUp()

        var finished = false
        if !LocalAuthenticationManager.shared.isAuthenticated {
            LocalAuthenticationManager.shared.authenticate(reason: "Testing", withMainContext: true).done { result in
                finished = true
            }.catch { error in
                fatalError("Failed to get context: \(error.localizedDescription)")
            }
        } else {
            finished = true
        }

        while !finished {
            RunLoop.current.run(mode: .default, before: Date.distantFuture)
        }
    }

    override func setUp() {
        super.setUp()
        TestHelper.createSeed()
    }
    
    override func tearDown() {
        super.tearDown()
        TestHelper.deleteLocalData()
    }
    
    // MARK: - Unit tests

    func testInitDoesntThrow() {
        XCTAssertNoThrow(try UserAccount(username: TestHelper.username, sites: [TestHelper.sampleSite], password: nil, rpId: nil, algorithms: nil, notes: nil, askToChange: nil))
        XCTAssertNoThrow(try UserAccount(username: TestHelper.username + "2", sites: [TestHelper.sampleSite], password: "password", rpId: nil, algorithms: nil, notes: nil, askToChange: nil))
    }
    
    func testNextPassword() {
        let site = TestHelper.sampleSite
        do {
            var account = try UserAccount(username: TestHelper.username, sites: [site], password: nil, rpId: nil, algorithms: nil, notes: nil, askToChange: nil)
            XCTAssertEqual(try account.nextPassword(), "[jh6eAX)og7A#nJ1:YDSrD6#61cf${\"A")
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testNextPasswordV1_1() {
        let site = TestHelper.sampleSiteV1_1
        do {
            var account = try UserAccount(username: TestHelper.username, sites: [site], password: nil, rpId: nil, algorithms: nil, notes: nil, askToChange: nil)
            XCTAssertEqual(try account.nextPassword(), "-S1tV2470vfm^9c[u{=*@zI7;FC>t+}t")
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testOneTimePasswordToken() {
        let site = TestHelper.sampleSite
        do {
            let account = try UserAccount(username: TestHelper.username, sites: [site], password: nil, rpId: nil, algorithms: nil, notes: nil, askToChange: nil)
            TestHelper.saveHOTPToken(id: account.id)
            let token = try account.oneTimePasswordToken()
            XCTAssertNotNil(token)
            XCTAssertEqual(token!.currentPassword!, "876735")                   // First HOTP password
            XCTAssertEqual(token!.updatedToken().currentPassword!, "086479")    // Second HOTP password
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
            var account = try UserAccount(username: TestHelper.username, sites: [TestHelper.sampleSite], password: nil, rpId: nil, algorithms: nil, notes: nil, askToChange: nil)
            XCTAssertNoThrow(try account.setOtp(token: token))
            XCTAssertNoThrow(try account.setOtp(token: token)) // To call update instead of save
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    func testDeleteOtp() {
        do {
            var account = try UserAccount(username: TestHelper.username, sites: [TestHelper.sampleSite], password: nil, rpId: nil, algorithms: nil, notes: nil, askToChange: nil)
            TestHelper.saveHOTPToken(id: account.id)
            XCTAssertNoThrow(try account.deleteOtp())
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    func testAddSite() {
        do {
            var account = try UserAccount(username: TestHelper.username, sites: [TestHelper.sampleSite], password: nil, rpId: nil, algorithms: nil, notes: nil, askToChange: nil)
            XCTAssertNoThrow(try account.addSite(site: TestHelper.sampleSite))
            XCTAssertEqual(account.sites.count, 2)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    func testRemoveSite() {
        do {
            var account = try UserAccount(username: TestHelper.username, sites: [TestHelper.sampleSite], password: nil, rpId: nil, algorithms: nil, notes: nil, askToChange: nil)
            try account.addSite(site: Site(name: "test", id: "testid", url: "https://example.com", ppd: nil))
            XCTAssertNoThrow(try account.removeSite(forIndex: 0))
            XCTAssertEqual(account.sites.count, 1)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    func testUpdateSite() {
        do {
            var account = try UserAccount(username: TestHelper.username, sites: [TestHelper.sampleSite], password: nil, rpId: nil, algorithms: nil, notes: nil, askToChange: nil)
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
            var account = try UserAccount(username: TestHelper.username, sites: [TestHelper.sampleSite], password: nil, rpId: nil, algorithms: nil, notes: nil, askToChange: nil)
            XCTAssertNoThrow(try account.update(username: TestHelper.username, password: password, siteName: siteName, url: url, askToLogin: true, askToChange: false, enabled: true))
            XCTAssertNoThrow(try account.update(username: TestHelper.username, password: password, siteName: siteName, url: url, askToLogin: true, askToChange: nil, enabled: true))
            XCTAssertNoThrow(try account.update(username: TestHelper.username, password: nil, siteName: siteName, url: url, askToLogin: true, askToChange: nil, enabled: true))
            XCTAssertEqual(account.username, TestHelper.username)
            XCTAssertEqual(try account.password(), password)
            XCTAssertEqual(account.site.name, siteName)
            XCTAssertEqual(account.site.url, url)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    func testUpdatePasswordAfterConfirmation() {
        do {
            var account = try UserAccount(username: TestHelper.username, sites: [TestHelper.sampleSite], password: nil, rpId: nil, algorithms: nil, notes: nil, askToChange: nil)
            XCTAssertNoThrow(try account.updatePasswordAfterConfirmation(context: nil))
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    func testDelete() {
        let expectation = XCTestExpectation(description: "Finish testDelete")
        do {
            let account = try UserAccount(username: TestHelper.username, sites: [TestHelper.sampleSite], password: nil, rpId: nil, algorithms: nil, notes: nil, askToChange: nil)
            let accountId = account.id
            account.delete().done { (result) in
                XCTAssertNil(try UserAccount.get(id: accountId, context: nil))
            }.catch { error in
                XCTFail(error.localizedDescription)
            }.finally {
                expectation.fulfill()
            }
        } catch {
            XCTFail(error.localizedDescription)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testPassword() {
        let expectation = XCTestExpectation(description: "Finish testPassword")
        do {
            let account = try UserAccount(username: TestHelper.username, sites: [TestHelper.sampleSite], password: nil, rpId: nil, algorithms: nil, notes: nil, askToChange: nil)
            account.password(reason: "Testing", type: .ifNeeded).done { (password) in
                XCTAssertEqual(password, "vGx$85gzsLZ/eK23ngx[afwG^0?#y%]C")
            }.catch {
                XCTFail($0.localizedDescription)
            }.finally {
                expectation.fulfill()
            }
        } catch {
            XCTFail(error.localizedDescription)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10.0)
    }

    func testPasswordV1_1() {
        let expectation = XCTestExpectation(description: "Finish testPassword")
        do {
            let account = try UserAccount(username: TestHelper.username, sites: [TestHelper.sampleSiteV1_1], password: nil, rpId: nil, algorithms: nil, notes: nil, askToChange: nil)
            account.password(reason: "Testing", type: .ifNeeded).done { (password) in
                XCTAssertEqual(password, "{W(1s?wt_3b<Y.V`tzltDEW%(OmR17~R")
            }.catch {
                XCTFail($0.localizedDescription)
            }.finally {
                expectation.fulfill()
            }
        } catch {
            XCTFail(error.localizedDescription)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testAll() {
        XCTAssertNoThrow(try UserAccount.all(context: nil))
        XCTAssertTrue(try UserAccount.all(context: nil).isEmpty)
        XCTAssertNoThrow(try UserAccount(username: TestHelper.username, sites: [TestHelper.sampleSite], password: nil, rpId: nil, algorithms: nil, notes: nil, askToChange: nil))
        XCTAssertNoThrow(try UserAccount.all(context: nil))
        XCTAssertFalse(try UserAccount.all(context: nil).isEmpty)
    }
    
    func testGetUserAccount() {
        XCTAssertNil(try UserAccount.get(id: "noid", context: nil))
    }
    
    func testSave() {
        guard let accountData = TestHelper.backupData.fromBase64 else {
            return XCTFail("Error converting to data")
        }
        do {
            let backupObject = try JSONDecoder().decode(BackupUserAccount.self, from: accountData)
            try UserAccount.create(backupObject: backupObject, context: nil)
            XCTAssertNotNil(try UserAccount.get(id: TestHelper.userID, context: nil))
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    func testAccountList() {
        XCTAssertNoThrow(try UserAccount.combinedSessionAccounts())
        XCTAssertTrue(try UserAccount.combinedSessionAccounts().isEmpty)
    }

    func testDeleteAll() {
        XCTAssertNoThrow(try UserAccount(username: TestHelper.username, sites: [TestHelper.sampleSite], password: nil, rpId: nil, algorithms: nil, notes: nil, askToChange: nil))
        XCTAssertNoThrow(try UserAccount(username: TestHelper.username + "2", sites: [TestHelper.sampleSite], password: nil, rpId: nil, algorithms: nil, notes: nil, askToChange: nil))
        UserAccount.deleteAll()
        XCTAssertEqual(try UserAccount.all(context: nil).count, 0)
    }
    
    func testUpdateVersion() {
        do {
            var account = try UserAccount(username: TestHelper.username, sites: [TestHelper.sampleSite], password: nil, rpId: nil, algorithms: nil, notes: nil, askToChange: nil)
            account.updateVersion(context: nil)
            account.version = 0
            account.updateVersion(context: nil)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    // MARK: - Integration Tests
    
    func testDeleteAndSyncAndGet() {
        let expectation = XCTestExpectation(description: "Finish testDeleteAndSyncAndGet")
        do {
            let account = try UserAccount(username: TestHelper.username, sites: [TestHelper.sampleSite], password: nil, rpId: nil, algorithms: nil, notes: nil, askToChange: nil)
            let accountId = account.id
            account.delete().done { (result) in
                XCTAssertNil(try UserAccount.get(id: accountId, context: nil))
            }.catch {
                XCTFail($0.localizedDescription)
            }.finally {
                expectation.fulfill()
            }
        } catch {
            XCTFail(error.localizedDescription)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10.0)
    }

    func testUpdatePasswordAndConfirm() {
        do {
            var account = try UserAccount(username: TestHelper.username, sites: [TestHelper.sampleSite], password: nil, rpId: nil, algorithms: nil, notes: nil, askToChange: nil)
            let newPassword = try account.nextPassword()
            XCTAssertNotEqual(newPassword, try account.password())
            XCTAssertNoThrow(try account.updatePasswordAfterConfirmation(context: nil))
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
            var account = try UserAccount(username: TestHelper.username, sites: [TestHelper.sampleSite], password: nil, rpId: nil, algorithms: nil, notes: nil, askToChange: nil)
            XCTAssertNoThrow(try account.setOtp(token: token))
            XCTAssertNoThrow(try account.deleteOtp())
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    func testAddSiteAndRemoveSite() {
        do {
            var account = try UserAccount(username: TestHelper.username, sites: [TestHelper.sampleSite], password: nil, rpId: nil, algorithms: nil, notes: nil, askToChange: nil)
            XCTAssertNoThrow(try account.addSite(site: TestHelper.sampleSite))
            XCTAssertEqual(account.sites.count, 2)
            XCTAssertNoThrow(try account.removeSite(forIndex: 0))
            XCTAssertEqual(account.sites.count, 1)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
}
