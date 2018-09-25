//
//  BackupTests.swift
//  keynTests
//
//  Created by Bas Doorn on 22/09/2018.
//  Copyright © 2018 keyn. All rights reserved.
//

import XCTest

@testable import keyn

class BackupTests: XCTestCase {

    override func setUp() {
        TestHelper.createSeed()
    }

    override func tearDown() {
        TestHelper.resetKeyn()
    }

    func testGetBackup() {
        let expectation = XCTestExpectation(description: "Download backup data")
        XCTAssertNoThrow(try BackupManager.sharedInstance.getBackupData {
            expectation.fulfill()
            })
        wait(for: [expectation], timeout: TimeInterval(exactly: 100)!)
    }

    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
