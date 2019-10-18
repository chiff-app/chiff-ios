//
//  PPDTests.swift
//  keynTests
//
//  Created by brandon maldonado alonso on 9/11/19.
//  Copyright © 2019 keyn. All rights reserved.
//

import XCTest

@testable import keyn

class PPDTests: XCTestCase {
    
    func testGet() {
        API.shared = MockAPI()
        PPD.get(id: "1") { (ppd) in
            XCTAssertNotNil(ppd)
        }
        PPD.get(id: "2") { (ppd) in
            XCTAssertNil(ppd)
        }
        PPD.get(id: "3") { (ppd) in
            XCTAssertNil(ppd)
        }
    }
    
    func testGetFailsIfAPIFails() {
        API.shared = MockAPI(shouldFail: true)
        PPD.get(id: "iddoesntmatterforfakeapi") { (ppd) in
            XCTAssertNil(ppd)
        }
    }
    
}
