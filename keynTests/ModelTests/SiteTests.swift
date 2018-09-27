import XCTest

@testable import keyn

class SiteTests: XCTestCase {
    
    override func setUp() {
        // TODO
        // Set up some example sites. Actually this is now still
        // already done because we already use sample data.
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
    }

    func testGetReturnsSite() {
        do {
            let exp = expectation(description: "Get a site.")
            try Site.get(id: TestHelper.linkedInPPDHandle, completion: { (site) in
                XCTAssertNotNil(site)
                exp.fulfill()
            })
            waitForExpectations(timeout: 10, handler: nil)
        } catch {
            XCTFail("An error occured during setup: \(error)")
        }
    }

    func testGetReturnsNilIfNoSiteForID() {
        do {
            let exp = expectation(description: "Get a site.")
            try Site.get(id: "seeyalater!", completion: { (site) in
                XCTAssertNil(site)
                exp.fulfill()
            })
            waitForExpectations(timeout: 10, handler: nil)
        } catch {
            XCTFail("An error occured during setup: \(error)")
        }
    }

}
