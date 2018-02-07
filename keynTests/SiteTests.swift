import XCTest

@testable import keyn

class SiteTests: XCTestCase {
    let restrictions = PasswordRestrictions(length: 24, characters: [.lower, .numbers, .upper, .symbols])

    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
    }

    func testInitAssignsURL() {
        let site = Site(name : "Google", id: "0", urls: ["google.com", "accounts.google.com"], restrictions: restrictions)
        XCTAssertEqual(site.urls, ["google.com", "accounts.google.com"])
    }

}

