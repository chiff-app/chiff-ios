/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import XCTest

@testable import keyn
import OneTimePassword

class AccountTests: XCTestCase {

    var accountId: String!
    var site: Site!
    let username = "demo@keyn.io"

    override func setUp() {
        super.setUp()
        do {
            TestHelper.createSeed()
            let exp = expectation(description: "Waiting for getting site.")
            try Site.get(id: TestHelper.linkedInPPDHandle, completion: { (site) in
                guard let site = site else {
                    XCTFail("Could not find site.")
                    return
                }
                self.site = site
                self.accountId = "\(site.id)_\(self.username)".hash
                exp.fulfill()
            })
            waitForExpectations(timeout: 40, handler: nil)
        } catch {
            XCTFail("An error occured during setup: \(error)")
        }
    }
    
    override func tearDown() {
        super.tearDown()
        TestHelper.resetKeyn()
    }

    func testInitValidAccountWithPasswordDoesntThrow() throws {
        let _ = try Account(username: self.username, site: self.site, password: "hunter2")
        let account = try Account.get(accountID: accountId)
        XCTAssertNotNil(account)
    }
    
    func testInitValidAccountDoesntThrow() throws {
        let _ = try Account(username: self.username, site: self.site, password: nil)
        let account = try Account.get(accountID: accountId)
        XCTAssertNotNil(account)
    }
    
    func testInitInValidPasswordIndexWithoutPasswordDoesThrow() throws {
        XCTAssertThrowsError(try Account(username: username, site: site, passwordIndex: -1, password: nil)) { error in
            XCTAssertEqual(error as? CryptoError, CryptoError.indexOutOfRange)
        }
        let account = try Account.get(accountID: accountId)
        XCTAssertNil(account)
    }
    
    func testInitInValidPasswordIndexWithPasswordDoesThrow() throws {
        XCTAssertThrowsError(try Account(username: username, site: site, passwordIndex: -1, password: "hunter2")) { error in
            XCTAssertEqual(error as? CryptoError, CryptoError.indexOutOfRange)
        }
        let account = try Account.get(accountID: accountId)
        XCTAssertNil(account)
    }

    func testBackupDoesntThrow() throws {
        var account = try Account(username: username, site: site, password: nil)
        XCTAssertNotNil(account)
        try account.backup()
    }
    
    func testPasswordIsCorrectForCustom() throws {
        let account = try Account(username: username, site: site, password: "hunter2")
        let keychainPassword: String = try account.password()
        XCTAssertEqual("hunter2", keychainPassword)
    }

    func testPasswordIsCorrectForGenerated() throws {
        let account = try Account(username: username, site: site, password: nil)
        let keychainPassword: String = try account.password()
        XCTAssertEqual("(H$RW@9o;+S5h5@2wh-nVy/=)!af@Tc)", keychainPassword)
    }

    func testNextPassword() throws {
        var account = try Account(username: self.username, site: self.site, password: "hunter2")
        let password = try account.nextPassword()
        XCTAssertEqual(password, "Z|A|q[O:{LGr^Tnxvyf@W`Z3;R}T^R%P")
    }

    func testOneTimePasswordToken() throws {
        let account = try Account(username: username, site: site, password: nil)
        XCTAssertNil(try account.oneTimePasswordToken())
    }

    func testSetOtpTokenDoesntThrow() throws {
        var account = try Account(username: username, site: site, password: nil)
        try account.setOtp(token: TestHelper.token())
    }

    func testHasOtpReturnsTrue() throws {
        var account = try Account(username: username, site: site, password: nil)
        try account.setOtp(token: TestHelper.token())
        XCTAssertTrue(account.hasOtp())
    }

    func testHasOtpReturnsFalse() throws {
        let account = try Account(username: username, site: site, password: nil)
        XCTAssertEqual(account.hasOtp(), false)
    }

    func testDeleteOtpToken() throws {
        var account = try Account(username: username, site: site, password: nil)
        try account.setOtp(token: TestHelper.token())
        XCTAssertEqual(account.hasOtp(), true)
        try account.deleteOtp()
        XCTAssertEqual(account.hasOtp(), false)
    }

    func testDeleteOtpTokenThrows() throws {
        var account = try Account(username: username, site: site, password: nil)
        XCTAssertEqual(account.hasOtp(), false)
        XCTAssertThrowsError(try account.deleteOtp())
    }
    
    func testUpdateUsername() throws {
        var account = try Account(username: username, site: site, password: nil)
        try account.update(username: "test", password: nil, siteName: nil, url: nil)
        XCTAssertEqual(account.username, "test")
    }
    
    func testUpdatePassword() throws {
        var account = try Account(username: username, site: site, password: "hunter2")
        try account.update(username: nil, password: "test", siteName: nil, url: nil)
        XCTAssertEqual(try account.password(), "test")
    }

    func testUpdatePasswordAfterConfirmation() throws {
        var account = try Account(username: username, site: site, password: "hunter2")
        try account.updatePasswordAfterConfirmation()
        XCTAssertEqual(try account.password(), "(H$RW@9o;+S5h5@2wh-nVy/=)!af@Tc)")
        let _ = try account.nextPassword()
        try account.updatePasswordAfterConfirmation()
        XCTAssertEqual(try account.password(), "Z|A|q[O:{LGr^Tnxvyf@W`Z3;R}T^R%P")
    }

    func testUpdateSiteName() throws {
        var account = try Account(username: username, site: site, password: "hunter2")
        try account.update(username: nil, password: nil, siteName: "test", url: nil)
        XCTAssertEqual(account.site.name, "test")
    }
    
    func testUpdateURL() throws {
        var account = try Account(username: username, site: site, password: "hunter2")
        try account.update(username: nil, password: nil, siteName: nil, url: "test")
        XCTAssertEqual(account.site.url, "test")
    }

    func testGetAccountWithSiteIDShouldHaveNoResults() throws {
        let accounts = try Account.get(siteID: "test")
        XCTAssertEqual(accounts.count, 0)
    }

    func testGetAccountWithSiteIDShouldHaveResult() throws {
        let _ = try Account(username: username, site: site, password: "hunter2")
        let id = "\(site.id)_\(username)".hash
        let accounts = try Account.get(siteID: site.id)
        XCTAssertEqual(accounts.first!.id, id)
    }

    func testGetAccountWithSiteIDShouldHaveResults() throws {
        let _ = try Account(username: "user1", site: site, password: "hunter1")
        let _ = try Account(username: "user2", site: site, password: "hunter2")
        let id1 = "\(site.id)_user1".hash
        let id2 = "\(site.id)_user2".hash
        let accounts = try Account.get(siteID: site.id)
        XCTAssertEqual(accounts.first!.id, id1)
        XCTAssertEqual(accounts.last!.id, id2)
    }

    func testGetAccountWithAccountIDShouldReturnNil() throws {
        let account = try Account.get(accountID: "id")
        XCTAssertNil(account)
    }

    func testGetAccountWithAccountIDShouldHaveResult() throws {
        let _ = try Account(username: username, site: site, password: "hunter2")
        let id = "\(site.id)_\(username)".hash
        let account = try Account.get(accountID: id)
        XCTAssertNotNil(account)
    }

    func testSaveAccount() {
        assert(false, "To be implemented.")
    }
    
    func testAllAccounts() throws {
        let _ = try Account(username: "user1", site: site, password: "hunter1")
        let _ = try Account(username: "user2", site: site, password: "hunter2")
        let _ = try Account(username: "user3", site: site, password: "hunter3")
        XCTAssertEqual(try Account.all().count, 3)
    }
    
    func testDeleteAllAccounts() throws {
        let _ = try Account(username: "user1", site: site, password: "hunter1")
        let _ = try Account(username: "user2", site: site, password: "hunter2")
        let _ = try Account(username: "user3", site: site, password: "hunter3")
        Account.deleteAll()
        XCTAssertEqual(try Account.all().count, 0)
    }
    
}
