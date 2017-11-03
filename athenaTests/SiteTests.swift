import XCTest
@testable import athena

class SiteTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testInitAssignsURL() {
        let site = Site(id: "GOOGLE", urls: ["google.com", "accounts.google.com"])
        XCTAssertEqual(site.urls, ["google.com", "accounts.google.com"])
    }

}

