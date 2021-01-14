//
//  PPDTests.swift
//  chiffTests
//
//  Copyright: see LICENSE.md
//

import XCTest
import PromiseKit

@testable import chiff

class PPDTests: XCTestCase {
    
    func testGet1() {
        let expectation = XCTestExpectation(description: "Finish testGet1")
        API.shared = MockAPI()
        PPD.get(id: "465359316cf124ca28f33cfb920fdacba6506ae2329dfd18669b3c6a3f52fadc", organisationKeyPair: nil).done {
            XCTAssertNotNil($0)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)
    }

    func testGet2() {
        let expectation = XCTestExpectation(description: "Finish testGet2")
        API.shared = MockAPI()
        PPD.get(id: "2", organisationKeyPair: nil).done {
            XCTAssertNil($0)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)
    }

    func testGet3() {
        let expectation = XCTestExpectation(description: "Finish testGet3")
        API.shared = MockAPI()
        PPD.get(id: "3", organisationKeyPair: nil).done {
            XCTAssertNil($0)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)
    }

    func testGetRedirect() {
        let expectation = XCTestExpectation(description: "Finish testGetRedirect")
        API.shared = MockAPI()
        PPD.get(id: "3ce8c236a3bd3307e737a8aa14b8a520f37b2e3386555c9a269141332f4c746e", organisationKeyPair: nil).done { ppd in
            if let ppd = ppd {
                XCTAssert(ppd.url == "https://my.london.ac.uk")
            } else {
                XCTFail("PPD was nil")
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)
    }


    func testGetFailsIfAPIFails() {
        let expectation = XCTestExpectation(description: "Finish testGetFailsIfAPIFails")
        API.shared = MockAPI(shouldFail: true)
        PPD.get(id: "iddoesntmatterforfakeapi", organisationKeyPair: nil).done {
            XCTAssertNil($0)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)
    }
    
}
