import XCTest

@testable import keyn

class AccountTests: XCTestCase {

    var site: Site!

    override func setUp() {
        super.setUp()
        site = Site.get(id: 0)
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
