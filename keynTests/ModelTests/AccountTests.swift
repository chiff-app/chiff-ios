import XCTest

@testable import keyn

class AccountTests: XCTestCase {

    var site: Site!
    let linkedInPPDHandle = "c53526a0b5fc33cb7d089d53a45a76044ed5f4aea170956d5799d01b2478cdfa"

    override func setUp() {
        super.setUp()
        do {
            TestHelper.createSeed()
            let exp = expectation(description: "Waiting for getting site.")
            try Site.get(id: linkedInPPDHandle, completion: { (site) in
                self.site = site
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

    func testInitValidAccountDoesntThrow() {
        XCTAssertNoThrow(
            try Account(username: "user@example.com", site: site, password: "pass123")
        )
    }
    
    func testBackupDoesntThrow() {
        
    }
    
    func testPasswordDoesntThrow() {
        
    }
    
    func testNextPassword() {
        
    }
    
    func testAddOtpTokenDoesntThrow() {
        
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
        
    }
    
    func testSaveAccount() {
    
    }
    
    func testAllAccounts() {
        
    }
    
    func testDeleteAllAccounts() {
        
    }

}
