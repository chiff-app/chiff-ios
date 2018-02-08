import XCTest

@testable import keyn

class SiteTests: XCTestCase {
    let restrictions = TestHelper.examplePasswordRestrictions()

    override func setUp() {
        // TODO
        // Set up some example sites. Actually this is now still
        // already done because we already use sample data.
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
    }

    func testInitAssignsURL() {
        let site = Site(name : "Google", id: "0", urls: ["google.com", "accounts.google.com"], restrictions: restrictions)
        XCTAssertEqual(site.urls, ["google.com", "accounts.google.com"])
    }

    func testGetReturnsSite() {
        let site = Site.get(id: "0")
        XCTAssertNotNil(site)
    }

    func testGetReturnsNilIfNoSiteForID() {
        let site = Site.get(id: "1000")
        XCTAssertNil(site)
    }

}
