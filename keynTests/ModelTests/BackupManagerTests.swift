/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import XCTest

@testable import keyn

class BackupManagerTests: XCTestCase {

    override func setUp() {
        TestHelper.setUp()
        TestHelper.setUpBackupManager() // probably needed here
    }

    override func tearDown() {
        TestHelper.tearDown()
        TestHelper.tearDownBackupManager() // probably needed here
    }
    
    func testBackupInitializationDoesntThrow() {
        
    }
    
    func testBackup() {
        
    }
    
    func testDeleteAccount() {
        
    }
    
    func testGetBackupData() {
        let expectation = XCTestExpectation(description: "Download backup data")

        XCTAssertNoThrow(try BackupManager.shared.getBackupData {
            expectation.fulfill()
        })

        wait(for: [expectation], timeout: TimeInterval(exactly: 100)!)
    }
    
    func testSignMessage() {
        
    }
    
    func testDeleteAllKeys() {
        
    }

}
