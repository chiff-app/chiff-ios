//
//  PPDTests.swift
//  keynTests
//
//  Created by brandon maldonado alonso on 9/11/19.
//  Copyright © 2019 keyn. All rights reserved.
//

import XCTest
import PromiseKit

@testable import keyn

class PPDTests: XCTestCase {
    
    func testGet() {
        API.shared = MockAPI()
        PPD.get(id: "1").done { XCTAssertNotNil($0) }
        PPD.get(id: "2").done { XCTAssertNil($0) }
        PPD.get(id: "3").done { XCTAssertNil($0) }
    }
    
    func testGetFailsIfAPIFails() {
        API.shared = MockAPI(shouldFail: true)
        PPD.get(id: "iddoesntmatterforfakeapi").done { XCTAssertNil($0) }
    }
    
}
