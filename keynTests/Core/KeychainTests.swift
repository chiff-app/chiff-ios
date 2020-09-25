//
//  Keychain.swift
//  keynTests
//
//  Created by brandon maldonado alonso on 9/5/19.
//  Copyright © 2019 keyn. All rights reserved.
//

import XCTest
import LocalAuthentication
import PromiseKit

@testable import keyn

class KeychainTests: XCTestCase {

    var context: LAContext!
    
    override func setUp() {
        let exp = expectation(description: "Get an authenticated context")
        LocalAuthenticationManager.shared.authenticate(reason: "Testing", withMainContext: true).done { context in
            self.context = context
        }.ensure {
            exp.fulfill()
        }.catch { error in
            fatalError("Failed to get context: \(error.localizedDescription)")
        }
        waitForExpectations(timeout: 40, handler: nil)
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
        TestHelper.deleteLocalData()
    }
    
    // MARK: - Unit Tests
    
    func testSaveDoesntThrow() {
        XCTAssertNoThrow(try Keychain.shared.save(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, secretData: "secretKey".data))
        XCTAssertNoThrow(try Keychain.shared.save(id: "signing", service: .signingSessionKey, secretData: "privateKey".data)) // To cover restricted
    }
    
    func testSaveDuplicateSeedThrows() {
        XCTAssertNoThrow(try Keychain.shared.save(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, secretData: "secretKey".data))
        XCTAssertThrowsError(try Keychain.shared.save(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, secretData: "secretKey".data))
    }
    
    func testGetThrowsIfNoSeed() {
        XCTAssertNil(try Keychain.shared.get(id: KeyIdentifier.master.identifier(for: .seed), service: .seed))
    }
    
    func testGetThrowsIfSeedDataIsEmpty() {
        TestHelper.createEmptySeed()
        do {
            let _ = try Keychain.shared.get(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, context: context)
        } catch let error {
            XCTAssertEqual(error.localizedDescription, KeychainError.unexpectedData.localizedDescription)
        }
    }
    
    func testGetThrowsIfContextIsInvalid() {
        let context = LAContext()
        context.invalidate()
        XCTAssertThrowsError(try Keychain.shared.get(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, context: context))
    }
    
    func testHasFalseIfNoSeed() {
        XCTAssertFalse(Keychain.shared.has(id: KeyIdentifier.master.identifier(for: .seed), service: .seed))
    }
    
    func testHas() {
        TestHelper.createSeed()
        XCTAssertTrue(Keychain.shared.has(id: KeyIdentifier.master.identifier(for: .seed), service: .seed))
    }
    
    func testUpdateThrowsIfNoSeedToUpdate() {
        let updatedData = "secretKeyUpdated".data
        XCTAssertThrowsError(try Keychain.shared.update(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, secretData: updatedData, objectData: nil))
    }
    
    func testAllNotNil() {
        TestHelper.createSeed()
        XCTAssertNotNil(try Keychain.shared.all(service: .seed, context: context))
    }
    
    func testAllThrowsIfInvalidContext() {
        let context = LAContext()
        context.invalidate()
        XCTAssertThrowsError(try Keychain.shared.all(service: .seed, context: context))
    }
    
    func testAttributesDoesntThrow() {
        TestHelper.createSeed()
        XCTAssertNoThrow(try Keychain.shared.attributes(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, context: context))
    }
    
    func testAttributesNotNil() {
        TestHelper.createSeed()
        XCTAssertNotNil(try Keychain.shared.attributes(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, context: context))
        
    }
    
    func testAttributesNilIfNoSeed() {
        XCTAssertNil(try Keychain.shared.attributes(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, context: LAContext()))
    }
    
    func testAttributesThrowIfInvalidContext() {
        let context = LAContext()
        context.invalidate()
        XCTAssertThrowsError(try Keychain.shared.attributes(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, context: context))
    }
    
    func testDeleteThrowsIfNoSeed() {
        XCTAssertThrowsError(try Keychain.shared.delete(id: KeyIdentifier.master.identifier(for: .seed), service: .seed))
    }
    
    func testDelete() {
        TestHelper.createSeed()
        XCTAssertNoThrow(try Keychain.shared.delete(id: KeyIdentifier.master.identifier(for: .seed), service: .seed))
    }
    

    func testGetAsyncWithEmptySeed() {
        let expectation = XCTestExpectation(description: "Finish testGetAsyncWithEmptySeed")
        TestHelper.createEmptySeed()
        Keychain.shared.get(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, reason: "Retrieve password", authenticationType: .ifNeeded).done { (value) in
            XCTAssertNil(value)
        }.ensure {
            expectation.fulfill()
        }.catch { error in
            XCTFail(error.localizedDescription)
        }
        wait(for: [expectation], timeout: 3.0)
    }
    
    func testGetAsync() {
        let expectation = XCTestExpectation(description: "Finish testGetAsync")
        TestHelper.createSeed()
        Keychain.shared.get(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, reason: "Retrieve password", with: self.context, authenticationType: .ifNeeded).ensure {
            expectation.fulfill()
        }.catch { error in
            XCTFail(error.localizedDescription)
        }
        wait(for: [expectation], timeout: 3.0)
    }
    
    func testGetAsyncThrowsIfInvalidContext() {
        let expectation = XCTestExpectation(description: "Finish testGetAsyncThrowsIfInvalidContext")
        let context = LAContext()
        context.invalidate()
        Keychain.shared.get(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, reason: "Retrieve password", with: context, authenticationType: .ifNeeded).ensure {
            expectation.fulfill()
        }.catch { error in
            XCTFail(error.localizedDescription)
        }
        wait(for: [expectation], timeout: 3.0)
    }
    
    func testGetAsyncFailsIfNoSeed() {
        let expectation = XCTestExpectation(description: "Finish testGetAsyncFailsIfNoSeed")
        Keychain.shared.get(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, reason: "Retrieve password", with: self.context, authenticationType: .ifNeeded).done { (value) in
            XCTAssertNil(value)
        }.ensure {
            expectation.fulfill()
        }.catch { error in
            XCTFail(error.localizedDescription)
        }
        wait(for: [expectation], timeout: 3.0)
    }
    
    func testDeleteAsync() {
        let expectation = XCTestExpectation(description: "Finish testDeleteAsync")
        TestHelper.createSeed()
        Keychain.shared.delete(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, reason: "Delete password", authenticationType: .ifNeeded, with: self.context).ensure {
            expectation.fulfill()
        }.catch { error in
            XCTFail(error.localizedDescription)
        }
        wait(for: [expectation], timeout: 3.0)
    }
    
    func testDeleteAsyncFailsIfInvalidContext() {
        let expectation = XCTestExpectation(description: "Finish testDeleteAsyncFailsIfInvalidContext")
        let context = LAContext()
        context.invalidate()
        Keychain.shared.delete(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, reason: "Delete password", authenticationType: .ifNeeded, with: context).done { _ in
             XCTFail("Should fail")
        }.ensure {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)
    }
    
    func testDeleteAsyncFailsIfNoSeed() {
        let expectation = XCTestExpectation(description: "Finish testDeleteAsyncFailsIfNoSeed")
        Keychain.shared.delete(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, reason: "Delete password", authenticationType: .ifNeeded).done { _ in
             XCTFail("Should fail")
        }.ensure {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)
    }
    
    // MARK: - Integration Tests
    
    func testSaveAndGet() {
        let expectation = XCTestExpectation(description: "Finish testSaveAndGet")
        let initialData = "secretKey".data
        XCTAssertNoThrow(try Keychain.shared.save(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, secretData: initialData))
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Testing") { (_, _) in
            do {
                let data = try Keychain.shared.get(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, context: self.context)
                XCTAssertEqual(data, initialData)
            } catch {
                XCTFail("Error getting data: \(error)")
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testSaveAndUpdateThrowsIfNoUpdateSeed() {
        let initialData = "secretKey".data
        XCTAssertNoThrow(try Keychain.shared.save(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, secretData: initialData))
        XCTAssertThrowsError(try Keychain.shared.update(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, secretData: nil, objectData: nil, context: LAContext()))
    }
    
    func testSaveAndUpdateThrowsIfInvalidContext() {
        let initialData = "secretKey".data
        XCTAssertNoThrow(try Keychain.shared.save(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, secretData: initialData))
        let context = LAContext()
        context.invalidate()
        let updatedData = "secretKeyUpdated".data
        XCTAssertThrowsError(try Keychain.shared.update(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, secretData: updatedData, objectData: nil, context: context))
    }
    
    func testSaveAndUpdateAndGet() {
        let initialData = "secretKey".data
        XCTAssertNoThrow(try Keychain.shared.save(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, secretData: initialData))
        let expectation = XCTestExpectation(description: "Finish testSaveAndGet")
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Testing") { (_, _) in
            do {
               let updatedData = "secretKeyUpdated".data
                XCTAssertNoThrow(try Keychain.shared.update(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, secretData: updatedData, objectData: nil, context: self.context))
                let data = try Keychain.shared.get(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, context: self.context)
               XCTAssertEqual(data, updatedData)
           } catch {
               XCTFail("Error getting data: \(error)")
           }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testSaveAndAll() {
        let firstDataSample = "one".data
        let secondDataSample = "two".data
        XCTAssertNoThrow(try Keychain.shared.save(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, secretData: firstDataSample))
        XCTAssertNoThrow(try Keychain.shared.save(id: KeyIdentifier.master.identifier(for: .backup), service: .seed, secretData: secondDataSample))
        do {
            let data = try Keychain.shared.all(service: .seed, context: self.context)
            XCTAssertNotNil(data)
        } catch {
            XCTFail("Error getting data: \(error)")
        }
    }
    
    func testSaveAndDeleteAndGet() {
        let initialData = "secretKey".data
        XCTAssertNoThrow(try Keychain.shared.save(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, secretData: initialData))
        XCTAssertNoThrow(try Keychain.shared.delete(id: KeyIdentifier.master.identifier(for: .seed), service: .seed))
        XCTAssertNil(try Keychain.shared.get(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, context: LAContext()))
    }
    
    func testSaveAndDeleteAllAndGet() {
        TestHelper.createSeed()
        Keychain.shared.deleteAll(service: .seed)
        XCTAssertNil(try Keychain.shared.get(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, context: context))
        XCTAssertNil(try Keychain.shared.get(id: KeyIdentifier.password.identifier(for: .seed), service: .seed, context: context))
        XCTAssertNil(try Keychain.shared.get(id: KeyIdentifier.backup.identifier(for: .seed), service: .seed, context: context))
    }
    
    func testSaveAndGetAsync() {
        let expectation = XCTestExpectation(description: "Finish testSaveAndGetAsync")
        let initialData = "secretKey".data
        XCTAssertNoThrow(try Keychain.shared.save(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, secretData: initialData))
        Keychain.shared.get(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, reason: "Retrieve password", with: context, authenticationType: .ifNeeded).ensure {
            expectation.fulfill()
        }.catch { error in
            XCTFail(error.localizedDescription)
        }
        wait(for: [expectation], timeout: 3.0)
    }
    
    func testSaveAndDeleteAndGetAsync() {
        let expectation = XCTestExpectation(description: "Finish testSaveAndGetAsync")
        let initialData = "secretKey".data
        XCTAssertNoThrow(try Keychain.shared.save(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, secretData: initialData))
        Keychain.shared.delete(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, reason: "Delete password", authenticationType: .ifNeeded, with: context).then { (context: LAContext?) -> Promise<LAContext?> in
            XCTAssertNotNil(context)
            return .value(context)
        }.then { (context) in
            Keychain.shared.delete(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, reason: "Retrieve password", authenticationType: .ifNeeded, with: self.context)
        }.ensure {
            expectation.fulfill()
        }.catch { error in
            XCTAssertNotNil(error)
        }
    }
    
}
