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
    
    func testGet() {
        API.shared = MockAPI()
        PPD.get(id: "1", organisationKeyPair: nil).done { XCTAssertNotNil($0) }
        PPD.get(id: "2", organisationKeyPair: nil).done { XCTAssertNil($0) }
        PPD.get(id: "3", organisationKeyPair: nil).done { XCTAssertNil($0) }
    }
    
    func testGetFailsIfAPIFails() {
        API.shared = MockAPI(shouldFail: true)
        PPD.get(id: "iddoesntmatterforfakeapi", organisationKeyPair: nil).done { XCTAssertNil($0) }
    }
    
}
