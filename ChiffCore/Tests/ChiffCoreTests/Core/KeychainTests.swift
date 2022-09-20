//
//  Keychain.swift
//  ChiffCoreTests
//
//  Copyright: see LICENSE.md
//

import XCTest
import LocalAuthentication
import PromiseKit

@testable import ChiffCore

class KeychainTests: XCTestCase {

    static var context: LAContext!

    override static func setUp() {
        super.setUp()

        if !LocalAuthenticationManager.shared.isAuthenticated {
            LocalAuthenticationManager.shared.authenticate(reason: "Testing", withMainContext: true).done { result in
                context = result
            }.catch { error in
                fatalError("Failed to get context: \(error.localizedDescription)")
            }
        } else {
            context = LocalAuthenticationManager.shared.mainContext
        }

        while context == nil {
            RunLoop.current.run(mode: .default, before: Date.distantFuture)
        }
    }

    override func setUp() {
        Keychain.shared = MockKeychain()
    }
    
    override func tearDown() {
        super.tearDown()
        TestHelper.deleteLocalData()
    }
    
    // MARK: - Unit Tests
    
    func testSaveDoesntThrow() {
        XCTAssertNoThrow(try Keychain.shared.save(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, secretData: "secretKey".data))
        XCTAssertNoThrow(try Keychain.shared.save(id: "signing", service: .browserSession(attribute: .signing), secretData: "privateKey".data)) // To cover restricted
    }
    
    func testSaveDuplicateSeedThrows() {
        XCTAssertNoThrow(try Keychain.shared.save(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, secretData: "secretKey".data))
        XCTAssertThrowsError(try Keychain.shared.save(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, secretData: "secretKey".data))
    }
    
    func testGetThrowsIfNoSeed() {
        XCTAssertNil(try Keychain.shared.get(id: KeyIdentifier.master.identifier(for: .seed), service: .seed))
    }
    
    func testGetThrowsIfSeedDataIsEmpty() {
        do {
            try Keychain.shared.save(id: KeyIdentifier.master.identifier(for: .seed), service: KeychainService.seed, secretData: nil, objectData: nil, label: nil)
            let _ = try Keychain.shared.get(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, context: Self.context)
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
        XCTAssertNotNil(try Keychain.shared.all(service: .seed, context: Self.context))
    }
    
    func testAllThrowsIfInvalidContext() {
        let context = LAContext()
        context.invalidate()
        XCTAssertThrowsError(try Keychain.shared.all(service: .seed, context: context))
    }
    
    func testAttributesThrows() {
        TestHelper.createSeed()
        XCTAssertThrowsError(try Keychain.shared.attributes(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, context: Self.context))
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
        do {
            try Keychain.shared.save(id: KeyIdentifier.master.identifier(for: .seed), service: KeychainService.seed, secretData: nil, objectData: nil, label: nil)
        } catch {
            fatalError("Failed to save empty seed")
        }

        Keychain.shared.get(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, reason: "Retrieve password", authenticationType: .ifNeeded).done { (value) in
            XCTAssertNil(value)
        }.catch { error in
            XCTFail(error.localizedDescription)
        }.finally {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)
    }
    
    func testGetAsync() {
        let expectation = XCTestExpectation(description: "Finish testGetAsync")
        TestHelper.createSeed()
        Keychain.shared.get(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, reason: "Retrieve password", with: Self.context, authenticationType: .ifNeeded).catch { error in
            XCTFail(error.localizedDescription)
        }.finally {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)
    }
    
    func testGetAsyncThrowsIfInvalidContext() {
        let expectation = XCTestExpectation(description: "Finish testGetAsyncThrowsIfInvalidContext")
        let context = LAContext()
        context.invalidate()
        Keychain.shared.get(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, reason: "Retrieve password", with: context, authenticationType: .ifNeeded).done { _ in
            XCTFail("Should throw")
        }.catch { error in
            print("Expected error: \(error.localizedDescription)")
        }.finally {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)
    }
    
    func testGetAsyncFailsIfNoSeed() {
        let expectation = XCTestExpectation(description: "Finish testGetAsyncFailsIfNoSeed")
        Keychain.shared.get(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, reason: "Retrieve password", with: Self.context, authenticationType: .ifNeeded).done { (value) in
            XCTAssertNil(value)
        }.catch { error in
            XCTFail(error.localizedDescription)
        }.finally {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)
    }
    
    // MARK: - Integration Tests
    
    func testSaveAndGet() {
        let initialData = "secretKey".data
        XCTAssertNoThrow(try Keychain.shared.save(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, secretData: initialData))
        do {
            let data = try Keychain.shared.get(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, context: Self.context)
            XCTAssertEqual(data, initialData)
        } catch {
            XCTFail("Error getting data: \(error)")
        }
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
        do {
            let updatedData = "secretKeyUpdated".data
            XCTAssertNoThrow(try Keychain.shared.update(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, secretData: updatedData, objectData: nil, context: Self.context))
            let data = try Keychain.shared.get(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, context: Self.context)
            XCTAssertEqual(data, updatedData)
       } catch {
            XCTFail("Error getting data: \(error)")
       }
    }
    
    func testSaveAndAll() {
        let firstDataSample = "one".data
        let secondDataSample = "two".data
        XCTAssertNoThrow(try Keychain.shared.save(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, secretData: firstDataSample))
        XCTAssertNoThrow(try Keychain.shared.save(id: KeyIdentifier.master.identifier(for: .backup), service: .seed, secretData: secondDataSample))
        do {
            let data = try Keychain.shared.all(service: .seed, context: Self.context)
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
        XCTAssertNil(try Keychain.shared.get(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, context: Self.context))
        XCTAssertNil(try Keychain.shared.get(id: KeyIdentifier.password.identifier(for: .passwordSeed), service: .passwordSeed, context: Self.context))
        XCTAssertNil(try Keychain.shared.get(id: KeyIdentifier.backup.identifier(for: .seed), service: .seed, context: Self.context))
    }
    
    func testSaveAndGetAsync() {
        let expectation = XCTestExpectation(description: "Finish testSaveAndGetAsync")
        let initialData = "secretKey".data
        XCTAssertNoThrow(try Keychain.shared.save(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, secretData: initialData))
        Keychain.shared.get(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, reason: "Retrieve password", with: Self.context, authenticationType: .ifNeeded).catch { error in
            XCTFail(error.localizedDescription)
        }.finally {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)
    }
    
}
