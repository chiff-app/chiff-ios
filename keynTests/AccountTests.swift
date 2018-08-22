import XCTest

@testable import keyn

class AccountTests: XCTestCase {

    var site: Site!
    let linkedInPPDHandle = "c53526a0b5fc33cb7d089d53a45a76044ed5f4aea170956d5799d01b2478cdfa"

    override func setUp() {
        super.setUp()
//        site = Site.get(id: linkedInPPDHandle)
    }
    
    override func tearDown() {
        super.tearDown()
    }

    func testInitValidAccountDoesntThrow() {
//        XCTAssertNoThrow(
//            try Account(username: "user@example.com", site: site, password: "pass123")
//        )
    }

}
