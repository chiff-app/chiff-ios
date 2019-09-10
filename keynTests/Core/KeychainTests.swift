//
//  Keychain.swift
//  keynTests
//
//  Created by brandon maldonado alonso on 9/5/19.
//  Copyright © 2019 keyn. All rights reserved.
//

import XCTest

@testable import keyn

class KeychainTests: XCTestCase {
    
    override func setUp() {
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
        XCTAssertThrowsError(try Keychain.shared.get(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, context: FakeLAContext()))
    }
    
    func testGetThrowsIfSeedDataIsEmpty() {
        TestHelper.createEmptySeed()
        XCTAssertThrowsError(try Keychain.shared.get(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, context: FakeLAContext()))
    }
    
    func testGetThrowsIfContextIsInvalid() {
        let context = FakeLAContext()
        context.invalidate()
        XCTAssertThrowsError(try Keychain.shared.get(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, context: context))
    }
    
    func testHasFalseIfNoSeed() {
        XCTAssertFalse(Keychain.shared.has(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, context: FakeLAContext()))
    }
    
    func testHas() {
        TestHelper.createSeed()
        XCTAssertTrue(Keychain.shared.has(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, context: FakeLAContext()))
    }
    
    func testUpdateThrowsIfNoSeedToUpdate() {
        let updatedData = "secretKeyUpdated".data
        XCTAssertThrowsError(try Keychain.shared.update(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, secretData: updatedData, objectData: nil))
    }
    
    func testAllNotNil() {
        TestHelper.createSeed()
        XCTAssertNotNil(try Keychain.shared.all(service: .seed))
    }
    
    func testAllThrowsIfInvalidContext() {
        let context = FakeLAContext()
        context.invalidate()
        XCTAssertThrowsError(try Keychain.shared.all(service: .seed, context: context))
    }
    
    func testAttributesDoesntThrow() {
        TestHelper.createSeed()
        XCTAssertNoThrow(try Keychain.shared.attributes(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, context: FakeLAContext()))
    }
    
    func testAttributesNotNil() {
        TestHelper.createSeed()
        XCTAssertNotNil(try Keychain.shared.attributes(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, context: FakeLAContext()))
    }
    
    func testAttributesNilIfNoSeed() {
        XCTAssertNil(try Keychain.shared.attributes(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, context: FakeLAContext()))
    }
    
    func testAttributesThrowIfInvalidContext() {
        let context = FakeLAContext()
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
    
    func testIsSyncedThrowsIfNoSeed() {
        XCTAssertThrowsError(try Keychain.shared.isSynced(id: KeyIdentifier.master.identifier(for: .seed), service: .seed))
    }
    
    func testIsSynced() {
        TestHelper.createSeed()
        XCTAssertTrue(try Keychain.shared.isSynced(id: KeyIdentifier.master.identifier(for: .seed), service: .seed))
    }
    
    func testSetSyncedThrowsIfNoSeed() {
        XCTAssertThrowsError(try Keychain.shared.setSynced(value: true, id: KeyIdentifier.master.identifier(for: .seed), service: .seed))
    }
    
    func testGetAsyncWithEmptySeed() {
        TestHelper.createEmptySeed()
        Keychain.shared.get(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, reason: "Retrieve password", authenticationType: .ifNeeded) { (result) in
            if case .success(_) = result {
                XCTFail("Should fail")
            }
        }
    }
    
    func testGetAsync() {
        TestHelper.createSeed()
        Keychain.shared.get(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, reason: "Retrieve password", with: FakeLAContext(), authenticationType: .ifNeeded) { (result) in
            if case let .failure(error) = result {
                XCTFail(error.localizedDescription)
            }
        }
    }
    
    func testGetAsyncThrowsIfInvalidContext() {
        let context = FakeLAContext()
        context.invalidate()
        Keychain.shared.get(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, reason: "Retrieve password", with: context, authenticationType: .ifNeeded) { (result) in
            if case .success(_) = result {
                XCTFail("Should fail")
            }
        }
    }
    
    func testGetAsyncFailsIfNoSeed() {
        Keychain.shared.get(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, reason: "Retrieve password", with: FakeLAContext(), authenticationType: .ifNeeded) { (result) in
            if case .success(_) = result {
                XCTFail("There must be an error")
            }
        }
    }
    
    func testDeleteAsync() {
        TestHelper.createSeed()
        Keychain.shared.delete(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, reason: "Delete password", authenticationType: .ifNeeded, with: FakeLAContext()) { (result) in
            if case let .failure(error) = result {
                XCTFail(error.localizedDescription)
            }
        }
    }
    
    func testDeleteAsyncFailsIfInvalidContext() {
        let context = FakeLAContext()
        context.invalidate()
        Keychain.shared.delete(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, reason: "Delete password", authenticationType: .ifNeeded, with: context) { (result) in
            if case .success(_) = result {
                XCTFail("Should fail")
            }
        }
    }
    
    func testDeleteAsyncFailsIfNoSeed() {
        Keychain.shared.delete(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, reason: "Delete password", authenticationType: .ifNeeded) { (result) in
            if case .success(_) = result {
                XCTFail("There must be an error")
            }
        }
    }
    
    // MARK: - Integration Tests
    
    func testSaveAndGet() {
        let initialData = "secretKey".data
        XCTAssertNoThrow(try Keychain.shared.save(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, secretData: initialData))
        do {
            let data = try Keychain.shared.get(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, context: FakeLAContext())
            XCTAssertEqual(data, initialData)
        } catch {
            XCTFail("Error getting data: \(error)")
        }
    }
    
    func testSaveAndUpdateThrowsIfNoUpdateSeed() {
        let initialData = "secretKey".data
        XCTAssertNoThrow(try Keychain.shared.save(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, secretData: initialData))
        XCTAssertThrowsError(try Keychain.shared.update(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, secretData: nil, objectData: nil, context: FakeLAContext()))
    }
    
    func testSaveAndUpdateThrowsIfInvalidContext() {
        let initialData = "secretKey".data
        XCTAssertNoThrow(try Keychain.shared.save(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, secretData: initialData))
        let context = FakeLAContext()
        context.invalidate()
        let updatedData = "secretKeyUpdated".data
        XCTAssertThrowsError(try Keychain.shared.update(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, secretData: updatedData, objectData: nil, context: context))
    }
    
    func testSaveAndUpdateAndGet() {
        let initialData = "secretKey".data
        let context = FakeLAContext()
        XCTAssertNoThrow(try Keychain.shared.save(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, secretData: initialData))
        let updatedData = "secretKeyUpdated".data
        XCTAssertNoThrow(try Keychain.shared.update(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, secretData: updatedData, objectData: nil, context: context))
        do {
            let data = try Keychain.shared.get(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, context: context)
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
            let data = try Keychain.shared.all(service: .seed, context: FakeLAContext())
            XCTAssertNotNil(data)
        } catch {
            XCTFail("Error getting data: \(error)")
        }
    }
    
    func testSaveAndDeleteAndGet() {
        let initialData = "secretKey".data
        XCTAssertNoThrow(try Keychain.shared.save(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, secretData: initialData))
        XCTAssertNoThrow(try Keychain.shared.delete(id: KeyIdentifier.master.identifier(for: .seed), service: .seed))
        XCTAssertThrowsError(try Keychain.shared.get(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, context: FakeLAContext()))
    }
    
    func testSaveAndDeleteAllAndGet() {
        TestHelper.createSeed()
        let context = FakeLAContext()
        Keychain.shared.deleteAll(service: .seed)
        XCTAssertThrowsError(try Keychain.shared.get(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, context: context))
        XCTAssertThrowsError(try Keychain.shared.get(id: KeyIdentifier.password.identifier(for: .seed), service: .seed, context: context))
        XCTAssertThrowsError(try Keychain.shared.get(id: KeyIdentifier.backup.identifier(for: .seed), service: .seed, context: context))
    }
    
    func testSaveAndSetSyncAndIsSync() {
        let initialData = "secretKey".data
        XCTAssertNoThrow(try Keychain.shared.save(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, secretData: initialData))
        XCTAssertNoThrow(try Keychain.shared.setSynced(value: true, id: KeyIdentifier.master.identifier(for: .seed), service: .seed))
        XCTAssertTrue(try Keychain.shared.isSynced(id: KeyIdentifier.master.identifier(for: .seed), service: .seed))
    }
    
    func testSaveAndGetAsync() {
        let initialData = "secretKey".data
        XCTAssertNoThrow(try Keychain.shared.save(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, secretData: initialData))
        Keychain.shared.get(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, reason: "Retrieve password", with: FakeLAContext(), authenticationType: .ifNeeded) { (result) in
            if case let .failure(error) = result {
                XCTFail(error.localizedDescription)
            }
        }
    }
    
    func testSaveAndDeleteAndGetAsync() {
        let initialData = "secretKey".data
        XCTAssertNoThrow(try Keychain.shared.save(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, secretData: initialData))
        Keychain.shared.delete(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, reason: "Delete password", authenticationType: .ifNeeded, with: FakeLAContext()) { (result) in
            switch result {
            case .failure(let error): XCTFail(error.localizedDescription)
            case .success(_):
                Keychain.shared.delete(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, reason: "Retrieve password", authenticationType: .ifNeeded, with: FakeLAContext()) { (result) in
                    if case .success(_) = result {
                        XCTFail("There must be an error")
                    }
                }
            }
        }
    }
    
}
