//
//  PasswordGenerationTests.swift
//  keynTests
//
//  Created by bas on 08/02/2018.
//  Copyright © 2018 keyn. All rights reserved.
//

import XCTest

@testable import keyn

class PasswordGenerationTests: XCTestCase {

    let restrictions = TestHelper.examplePasswordRestrictions()
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.

    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testPasswordGeneration() {
        let site = Site(name : "Google", id: "0", urls: ["google.com", "accounts.google.com"], restrictions: restrictions)
        let randomIndex = Int(arc4random_uniform(100000000))
        let randomUsername = "TestUsername"
        do {
            let randomPassword = try Crypto.sharedInstance.generatePassword(username: randomUsername, passwordIndex: randomIndex, siteID: site.id, restrictions: restrictions, offset: nil)
            let offset = try Crypto.sharedInstance.calculatePasswordOffset(username: randomUsername, passwordIndex: randomIndex, siteID: site.id, restrictions: restrictions, password: randomPassword)
            let calculatedPassword = try Crypto.sharedInstance.generatePassword(username: randomUsername, passwordIndex: randomIndex, siteID: site.id, restrictions: restrictions, offset: offset)
            XCTAssertEqual(randomPassword, calculatedPassword)
        } catch {

        }
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
}
