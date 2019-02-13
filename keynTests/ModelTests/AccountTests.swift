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

    func testInitValidAccountWithPasswordDoesntThrow() {
        // Also saves account to Keychain.
        XCTAssertNoThrow(try Account(username: username, site: site, password: "Pass123."))
        let account = testIfAccountIsSaved()
        XCTAssertNotNil(account)
        XCTAssertNoThrow(try account?.delete())
    }
    
    func testInitValidAccountDoesntThrow() {
        // Also saves account to Keychain.
        XCTAssertNoThrow(try Account(username: username, site: site, password: nil))
        let account = testIfAccountIsSaved()
        XCTAssertNotNil(account)
        XCTAssertNoThrow(try account?.delete())
    }
    
    func testInitInValidPasswordIndexWithoutPasswordDoesThrow() {
        XCTAssertThrowsError(try Account(username: username, site: site, passwordIndex: -1, password: nil)) { error in
            XCTAssertEqual(error as? CryptoError, CryptoError.indexOutOfRange)
        }
        XCTAssertNil(testIfAccountIsSaved())
    }
    
    func testInitInValidPasswordIndexWithPasswordDoesThrow() {
        XCTAssertThrowsError(try Account(username: username, site: site, passwordIndex: -1, password: "Pass123.")) { error in
            XCTAssertEqual(error as? CryptoError, CryptoError.indexOutOfRange)
        }
        XCTAssertNil(testIfAccountIsSaved())
    }
    
    func testBackupDoesntThrow() {
        var account = try? Account(username: username, site: site, password: nil)
        XCTAssertNotNil(account)
        XCTAssertNoThrow(try account!.backup())
        XCTAssertNoThrow(try account?.delete())
    }
    
    func testPassword() {
        let password = "Passzzword12"
        let account = try? Account(username: username, site: site, password: password)
        XCTAssertNotNil(account)
        do {
            let keychainPassword: String = try account!.password()
            XCTAssertEqual(password, keychainPassword)
        } catch {
            XCTFail("Error getting password")
        }
        XCTAssertNoThrow(try account?.delete())
    }
    
    func testNextPassword() {
        var account = try? Account(username: username, site: site, password: nil)
        XCTAssertNotNil(account)
        XCTAssertNoThrow(try account!.nextPassword(offset: nil))
        XCTAssertNoThrow(try account?.delete())
    }
    
    func testAddOtpTokenDoesntThrow() {
        
    }
    
    func testOneTimePasswordToken() {
        let account = try? Account(username: username, site: site, password: nil)
        XCTAssertNoThrow(
            XCTAssertNil(try account?.oneTimePasswordToken())
        )
        XCTAssertNoThrow(try account?.delete())
    }
    

    
    func testUpdteOtpToken() {
        
    }
    
    func testDeleteOtpToken() {
        
    }
    
    func testUpdateUsername() {
        
    }
    
    func testUpdatePassword() {
        
    }
    
    func testUpdateSiteName() {
        
    }
    
    func testUpdateURL() {
        
    }
    
    func testGenerateNewPassword() {
        
    }
    
    func testGetAccountWithSiteID() {
        
    }
    
    func testGetAccountWithAccountID() {
//        do {
//            let account = Account.get(accountID: accountId)
//            XCTAssertNotNil(account)
//        }

    }
    
    func testSaveAccount() {
    
    }
    
    func testAllAccounts() {
        
    }
    
    func testDeleteAllAccounts() {
        
    }
    
    // Private methods
    
    private func testIfAccountIsSaved() -> Account? {
        do {
            return try Account.get(accountID: accountId)
        } catch {
            print("Error getting account: \(error)")
        }
        return nil
    }

}
