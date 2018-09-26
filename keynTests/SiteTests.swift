import XCTest

@testable import keyn

class SiteTests: XCTestCase {
    
    let linkedInPPDHandle = "c53526a0b5fc33cb7d089d53a45a76044ed5f4aea170956d5799d01b2478cdfa"
    
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
        XCTAssertNoThrow(try Site.get(id: linkedInPPDHandle) { (site) in
            XCTAssertNotNil(site)
        })

    }

    func testGetReturnsNilIfNoSiteForID() {
        XCTAssertNoThrow(try Site.get(id: "seeyalater!") { (site) in
            XCTAssertNil(site)
        })
    }

}
