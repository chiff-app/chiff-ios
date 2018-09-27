//
//  BackupTests.swift
//  keynTests
//
//  Created by Bas Doorn on 22/09/2018.
//  Copyright © 2018 keyn. All rights reserved.
//

import XCTest

@testable import keyn

class BackupManagerTests: XCTestCase {

    override func setUp() {
        TestHelper.createSeed()
    }

    override func tearDown() {
        TestHelper.resetKeyn()
    }
    
    func testBackupInitializationDoesntThrow() {
        
    }
    
    func testBackup() {
        
    }
    
    func testDeleteAccount() {
        
    }
    
    func testGetBackupData() {
        let expectation = XCTestExpectation(description: "Download backup data")
        XCTAssertNoThrow(try BackupManager.sharedInstance.getBackupData {
            expectation.fulfill()
            })
        wait(for: [expectation], timeout: TimeInterval(exactly: 100)!)
    }
    
    func testSignMessage() {
        
    }
    
    func testDeleteAllKeys() {
        
    }
}
