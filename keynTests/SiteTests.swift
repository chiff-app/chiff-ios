import XCTest

@testable import keyn

class SiteTests: XCTestCase {
    
    let ppd = TestHelper.examplePPD()

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
        let site = Site.get(id: 1)!
        XCTAssertEqual(site.urls, ["google.com", "accounts.google.com"])
    }

    func testGetReturnsSite() {
        let site = Site.get(id: 0)
        XCTAssertNotNil(site)
    }

    func testGetReturnsNilIfNoSiteForID() {
        let site = Site.get(id: 1000)
        XCTAssertNil(site)
    }

}
