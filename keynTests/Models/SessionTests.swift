//
//  SessionTests.swift
//  keynTests
//
//  Created by brandon maldonado alonso on 9/10/19.
//  Copyright © 2019 keyn. All rights reserved.
//
import XCTest
import LocalAuthentication
import PromiseKit

@testable import keyn

class SessionTests: XCTestCase {

    var context: LAContext!
    
    override func setUp() {
        super.setUp()
        let exp = expectation(description: "Get an authenticated context")
        LocalAuthenticationManager.shared.authenticate(reason: "Testing", withMainContext: true).done { context in
            self.context = context
            TestHelper.createSeed()
        }.ensure {
            exp.fulfill()
        }.catch { error in
            fatalError(error.localizedDescription)
        }
        waitForExpectations(timeout: 40, handler: nil)
        API.shared = MockAPI()
    }
    
    override func tearDown() {
        super.tearDown()
        TestHelper.deleteLocalData()
    }
    
    func testInitiate() {
        let expectation = XCTestExpectation(description: "Finish testInitiate")
        TestHelper.createEndpointKey()
        BrowserSession.initiate(pairingQueueSeed: TestHelper.pairingQueueSeed, browserPubKey: TestHelper.browserPublicKeyBase64, browser: .chrome, os: "prueba").ensure {
            expectation.fulfill()
        }.catch { error in
            XCTFail(error.localizedDescription)
        }
        wait(for: [expectation], timeout: 3.0)
    }
    
    func testInitiateFailsIfDuplicated() {
        let expectation = XCTestExpectation(description: "Finish testInitiate")
        TestHelper.createEndpointKey()
        BrowserSession.initiate(pairingQueueSeed: TestHelper.pairingQueueSeed, browserPubKey: TestHelper.browserPublicKeyBase64, browser: .chrome, os: "prueba").then { (result) in
            BrowserSession.initiate(pairingQueueSeed: TestHelper.pairingQueueSeed, browserPubKey: TestHelper.browserPublicKeyBase64, browser: .chrome, os: "prueba")
        }.done { _ in
            XCTFail("Should fail")
        }.ensure {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)
    }
    
    func testInitiateThrowsIfNoEndpointKey() {
        let expectation = XCTestExpectation(description: "Finish testInitiateThrowsIfNoEndpointKey")
        BrowserSession.initiate(pairingQueueSeed: TestHelper.pairingQueueSeed, browserPubKey: TestHelper.browserPublicKeyBase64, browser: .chrome, os: "prueba").done { _ in
            XCTFail("Should fail")
        }.ensure {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)
    }
    
    func testInitiateAndDeleteWithNotificationExtension() {
        let expectation = XCTestExpectation(description: "Finish testInitiateAndDeleteWithNotificationExtension")
        TestHelper.createEndpointKey()
        BrowserSession.initiate(pairingQueueSeed: TestHelper.pairingQueueSeed, browserPubKey: TestHelper.browserPublicKeyBase64, browser: .chrome, os: "prueba").then { (session) in
            session.delete(notify: true)
        }.ensure {
            expectation.fulfill()
        }.catch { error in
            XCTFail(error.localizedDescription)
        }
        wait(for: [expectation], timeout: 3.0)
    }
    
    func testInitiateAndDeleteWithoutNotificationExtension() {
        let expectation = XCTestExpectation(description: "Finish testInitiateAndDeleteWithoutNotificationExtension")
        TestHelper.createEndpointKey()
        BrowserSession.initiate(pairingQueueSeed: TestHelper.pairingQueueSeed, browserPubKey: TestHelper.browserPublicKeyBase64, browser: .chrome, os: "prueba").then { (session) in
            session.delete(notify: false)
        }.ensure {
            expectation.fulfill()
        }.catch { error in
            XCTFail(error.localizedDescription)
        }
        wait(for: [expectation], timeout: 3.0)
    }
    
    func testInitiateAndDeleteWithoutNotificationExtensionAndNoPrivateKey() {
        let expectation = XCTestExpectation(description: "Finish testInitiateAndDeleteWithoutNotificationExtensionAndNoPrivateKey")
        TestHelper.createEndpointKey()
        BrowserSession.initiate(pairingQueueSeed: TestHelper.pairingQueueSeed, browserPubKey: TestHelper.browserPublicKeyBase64, browser: .chrome, os: "prueba").then { (session) -> Promise<Void> in
            TestHelper.deleteLocalData()
            return session.delete(notify: false)
        }.done { _ in
            XCTFail("Should fail")
        }.ensure {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)
    }
    
    func testDecrypt() {
        let (_, _, pubKey) = TestHelper.createSharedKey()
        let session = BrowserSession(id: TestHelper.browserPublicKeyBase64.hash, signingPubKey: pubKey, browser: .chrome, title: "Chrome @ test", version: 0)
        XCTAssertNoThrow(try session.decrypt(message: TestHelper.keynRequestEncrypted))
    }
    
    func testCancelRequest() {
        let expectation = XCTestExpectation(description: "Finish testCancelRequest")
        let (_, _, pubKey) = TestHelper.createSharedKey()
        let session = BrowserSession(id: TestHelper.browserPublicKeyBase64.hash, signingPubKey: pubKey, browser: .chrome, title: "Chrome @ test", version: 0)
        session.cancelRequest(reason: .disabled, browserTab: 0).ensure {
            expectation.fulfill()
        }.catch { error in
            XCTFail(error.localizedDescription)
        }
        wait(for: [expectation], timeout: 3.0)
    }
    
    func testCancelRequestFailsIfNoKeys() {
        let expectation = XCTestExpectation(description: "Finish testCancelRequestFailsIfNoKeys")
        let (_, _, pubKey) = TestHelper.createSharedKey()
        TestHelper.deleteLocalData()
        let session = BrowserSession(id: TestHelper.browserPublicKeyBase64.hash, signingPubKey: pubKey, browser: .chrome, title: "Chrome @ test", version: 0)
        session.cancelRequest(reason: .disabled, browserTab: 0).done { _ in
            XCTFail("Should fail")
        }.ensure {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)
    }
    
    func testGetPersistentQueueMessages() {
        let expectation = XCTestExpectation(description: "Finish testGetPersistentQueueMessages")
        let (_, _, pubKey) = TestHelper.createSharedKey()
        API.shared = MockAPI(data: [["body": "gEys57UCuXijGtDFqlslsPktBd35zcugtt_WmTXdoCUVNmitUTGTGCJgAalrZFcwNQQz3_DQ7iW2yoxRfj0IJzEUvuApXQW6BCVuPAgwyI_q3gngrJI9nhDMf7PSNmQONPY9h8dON2G2yyfG_6IfxAX0xrEkD1NV4FryCSMON96KOr4Jpu1PPYmSyTCcGURoaQ45afI", "receiptHandle": "test"]])
        let session = BrowserSession(id: TestHelper.browserPublicKeyBase64.hash, signingPubKey: pubKey, browser: .chrome, title: "Chrome @ test", version: 0)
        session.getPersistentQueueMessages(shortPolling: true).ensure {
            expectation.fulfill()
        }.catch { error in
            XCTFail(error.localizedDescription)
        }
        wait(for: [expectation], timeout: 3.0)
    }
    
    func testGetPersistentQueueMessagesFailsWithoutData() {
        let expectation = XCTestExpectation(description: "Finish testGetPersistentQueueMessagesFailsWithoutData")
        let (_, _, pubKey) = TestHelper.createSharedKey()
        let session = BrowserSession(id: TestHelper.browserPublicKeyBase64.hash, signingPubKey: pubKey, browser: .chrome, title: "Chrome @ test", version: 0)
        session.getPersistentQueueMessages(shortPolling: true).done { _ in
            XCTFail("Should fail")
        }.ensure {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)
    }
    
    func testGetPersistentQueueMessagesFailsIfWrongData() {
        let expectation = XCTestExpectation(description: "Finish testGetPersistentQueueMessagesFailsIfWrongData")
        let (_, _, pubKey) = TestHelper.createSharedKey()
        API.shared = MockAPI(data: [["body": "gEys57UCuXijGtDFqlslsPktBd35zcugtt_WmTXdoCUVNmitUTGTGCJgAalrZFcwNQQz3_DQ7iW2yoxRfj0IJzEUvuApXQW6BCVuPAgwyI_q3gngrJI9nhDMf7PSNmQONPY9h8dON2G2yyfG_6IfxAX0xrEkD1NV4FryCSMON96KOr4Jpu1PPYmSyTCcGURoaQ45afI"]])
        let session = BrowserSession(id: TestHelper.browserPublicKeyBase64.hash, signingPubKey: pubKey, browser: .chrome, title: "Chrome @ test", version: 0)
        session.getPersistentQueueMessages(shortPolling: true).done { _ in
            XCTFail("Should fail")
        }.ensure {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)
    }
    
    func testGetPersistentQueueMessagesFailsIfNoKeys() {
        let expectation = XCTestExpectation(description: "Finish testGetPersistentQueueMessagesFailsIfNoKeys")
        let (_, _, pubKey) = TestHelper.createSharedKey()
        TestHelper.deleteLocalData()
        let session = BrowserSession(id: TestHelper.browserPublicKeyBase64.hash, signingPubKey: pubKey, browser: .chrome, title: "Chrome @ test", version: 0)
        session.getPersistentQueueMessages(shortPolling: true).done { _ in
            XCTFail("Should fail")
        }.ensure {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)
    }
    
    func testDeleteFromPersistentQueue() {
        // It doesn't really fails, as there is no completionHandler for deleteFromPersistentQueue
        let (_, _, pubKey) = TestHelper.createSharedKey()
        let session = BrowserSession(id: TestHelper.browserPublicKeyBase64.hash, signingPubKey: pubKey, browser: .chrome, title: "Chrome @ test", version: 0)
        session.deleteFromPersistentQueue(receiptHandle: "It doesn't matter")
    }
    
    func testDeleteFromPersistentQueueFailsIfAPIFails() {
        // It doesn't really fails, as there is no completionHandler for deleteFromPersistentQueue
        let (_, _, pubKey) = TestHelper.createSharedKey()
        API.shared = MockAPI(shouldFail: true)
        let session = BrowserSession(id: TestHelper.browserPublicKeyBase64.hash, signingPubKey: pubKey, browser: .chrome, title: "Chrome @ test", version: 0)
        session.deleteFromPersistentQueue(receiptHandle: "It doesn't matter")
    }
    
    func testDeleteFromPersistentQueueFailsIfNoKeys() {
        // It doesn't really fails, as there is no completionHandler for deleteFromPersistentQueue
        let (_, _, pubKey) = TestHelper.createSharedKey()
        TestHelper.deleteLocalData()
        let session = BrowserSession(id: TestHelper.browserPublicKeyBase64.hash, signingPubKey: pubKey, browser: .chrome, title: "Chrome @ test", version: 0)
        session.deleteFromPersistentQueue(receiptHandle: "It doesn't matter")
    }
    
    func testDeleteAccount() {
        // It doesn't really fails, as there is no completionHandler for deleteFromPersistentQueue
        let (_, _, pubKey) = TestHelper.createSharedKey()
        let session = BrowserSession(id: TestHelper.browserPublicKeyBase64.hash, signingPubKey: pubKey, browser: .chrome, title: "Chrome @ test", version: 0)
        session.deleteAccount(accountId: TestHelper.userID)
    }
    
    func testDeleteAccountFailsIfAPIFails() {
        // It doesn't really fails, as there is no completionHandler for deleteFromPersistentQueue
        let (_, _, pubKey) = TestHelper.createSharedKey()
        API.shared = MockAPI(shouldFail: true)
        let session = BrowserSession(id: TestHelper.browserPublicKeyBase64.hash, signingPubKey: pubKey, browser: .chrome, title: "Chrome @ test", version: 0)
        session.deleteAccount(accountId: TestHelper.userID)
    }
    
    func testDeleteAccountFailsIfNoKeys() {
        // It doesn't really fails, as there is no completionHandler for deleteFromPersistentQueue
        let (_, _, pubKey) = TestHelper.createSharedKey()
        TestHelper.deleteLocalData()
        let session = BrowserSession(id: TestHelper.browserPublicKeyBase64.hash, signingPubKey: pubKey, browser: .chrome, title: "Chrome @ test", version: 0)
        session.deleteAccount(accountId: TestHelper.userID)
    }
    
    func testAll() {
        XCTAssertNoThrow(try BrowserSession.all())
    }
    
    func testAllThrowsIFKeyAlreadyExist() {
        let _ = TestHelper.createSharedKey()
        XCTAssertThrowsError(try BrowserSession.all())
    }
    
    func testExists() {
        XCTAssertNoThrow(try BrowserSession.exists(id: TestHelper.browserPublicKeyBase64.hash))
        XCTAssertFalse(try BrowserSession.exists(id: TestHelper.browserPublicKeyBase64.hash))
        let expectation = XCTestExpectation(description: "Finish testInitiateAndSendCredentials")
        TestHelper.createEndpointKey()
        BrowserSession.initiate(pairingQueueSeed: TestHelper.pairingQueueSeed, browserPubKey: TestHelper.browserPublicKeyBase64, browser: .chrome, os: "prueba").done { (session) in
            XCTAssertTrue(try BrowserSession.exists(id: TestHelper.browserPublicKeyBase64.hash))
        }.ensure {
            expectation.fulfill()
        }.catch { error in
            XCTFail(error.localizedDescription)
        }
        wait(for: [expectation], timeout: 3.0)
    }
    
    func testGet() {
        let expectation = XCTestExpectation(description: "Finish testInitiateAndSendCredentials")
        TestHelper.createEndpointKey()
        BrowserSession.initiate(pairingQueueSeed: TestHelper.pairingQueueSeed, browserPubKey: TestHelper.browserPublicKeyBase64, browser: .chrome, os: "prueba").done { (session) in
            XCTAssertNoThrow(try BrowserSession.get(id: session.id, context: nil))
        }.ensure {
            expectation.fulfill()
        }.catch { error in
            XCTFail(error.localizedDescription)
        }
        wait(for: [expectation], timeout: 3.0)
    }
    
    func testGetNilIfNoData() {
        XCTAssertNoThrow(try BrowserSession.get(id: "session.id", context: nil))
        XCTAssertNil(try BrowserSession.get(id: "session.id", context: nil))
    }
    
    func testInitiateAndSendCredentials() {
        let expectation = XCTestExpectation(description: "Finish testInitiateAndSendCredentials")
        TestHelper.createEndpointKey()
        BrowserSession.initiate(pairingQueueSeed: TestHelper.pairingQueueSeed, browserPubKey: TestHelper.browserPublicKeyBase64, browser: .chrome, os: "prueba").done { (session) in
            let account = try UserAccount(username: TestHelper.username, sites: [TestHelper.sampleSite], password: nil, rpId: nil, algorithms: nil, notes: nil, context: self.context)
            guard var session = session as? BrowserSession else {
                return XCTFail("Casting error")
            }
            XCTAssertNoThrow(try session.sendCredentials(account: account, browserTab: 0, type: .change, context: self.context, newPassword: nil))
            XCTAssertNoThrow(try session.sendCredentials(account: account, browserTab: 0, type: .add, context: self.context, newPassword: nil))
            XCTAssertNoThrow(try session.sendCredentials(account: account, browserTab: 0, type: .login, context: self.context, newPassword: nil))
            XCTAssertNoThrow(try session.sendCredentials(account: account, browserTab: 0, type: .fill, context: self.context, newPassword: nil))
            XCTAssertNoThrow(try session.sendCredentials(account: account, browserTab: 0, type: .register, context: self.context, newPassword: nil))
            XCTAssertThrowsError(try session.sendCredentials(account: account, browserTab: 0, type: .end, context: self.context, newPassword: nil))
            API.shared = MockAPI(shouldFail: true)
            XCTAssertNoThrow(try session.sendCredentials(account: account, browserTab: 0, type: .fill, context: self.context, newPassword: nil))
        }.ensure {
            expectation.fulfill()
        }.catch { error in
            XCTFail(error.localizedDescription)
        }
        wait(for: [expectation], timeout: 5.0)
    }

    func testShouldNotFailOnOneUndecodableSession() {
        TestHelper.deleteLocalData()
        struct NotASession: Codable {
            let id: String
            let cookie: String
        }
        let notASession = NotASession(id: "ihaveanidea", cookie: "oreo")
        let session = TestHelper.createSessionInKeychain()
        let encoder = PropertyListEncoder()
        do {
            try Keychain.shared.save(id: "\(notASession.id)-fake", service: .sharedSessionKey, secretData: "secret".data, objectData: encoder.encode(notASession))
            let sessions = try BrowserSession.all()
            XCTAssertEqual(sessions.count, 1)
            XCTAssertEqual(sessions.first!.id, session.id)
        } catch {
            print(error)
            XCTFail(error.localizedDescription)
        }
    }

    func testShouldReturnNilOnWrongId() {
        let _ = BrowserSession.deleteAll()
        struct NotASession: Codable {
            let id: String
            let cookie: String
        }
        let notASession = NotASession(id: "ihaveanidea", cookie: "oreo")
        let keychainId = "\(notASession.id)-fake"
        let encoder = PropertyListEncoder()
        do {
            try Keychain.shared.save(id: keychainId, service: .sharedSessionKey, secretData: "secret".data, objectData: encoder.encode(notASession))
            XCTAssertNil(try BrowserSession.get(id: "ihaveanidea", context: nil))
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testShouldThrowOnSingleUndecodableSession() {
        let _ = BrowserSession.deleteAll()
        struct NotASession: Codable {
            let id: String
            let cookie: String
        }
        let notASession = NotASession(id: "ihaveanidea", cookie: "oreo")
        let keychainId = "\(notASession.id)-shared"
        let encoder = PropertyListEncoder()
        do {
            try Keychain.shared.save(id: keychainId, service: .sharedSessionKey, secretData: "secret".data, objectData: encoder.encode(notASession))
            XCTAssertThrowsError(try BrowserSession.get(id: "ihaveanidea", context: nil))
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testShouldThrowOnSingleIfUnfixable() {
        let _ = BrowserSession.deleteAll()
        struct NotASession: Codable {
            let id: String
            let cookie: String
        }
        let notASession = NotASession(id: "ihaveanidea", cookie: "oreo")
        let keychainId = "\(notASession.id)-shared"
        do {
            try saveWrongDataInKeychain(id: keychainId, service: .sharedSessionKey, secretData: "secret".data, objectData: 42)
            XCTAssertThrowsError(try BrowserSession.get(id: "ihaveanidea", context: nil))
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testShouldPurgeAllIfUnfixable() {
        let _ = BrowserSession.deleteAll()
        struct NotASession: Codable {
            let id: String
            let cookie: String
        }
        let notASession = NotASession(id: "ihaveanidea", cookie: "oreo")
        let encoder = PropertyListEncoder()
        do {
            try saveWrongDataInKeychain(id: 4, service: .sharedSessionKey, secretData: "secret".data, objectData: encoder.encode(notASession))
            let sessions = try BrowserSession.all()
            XCTAssertEqual(sessions.count, 0)
            print(sessions)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    // MARK: - Private functions

    private func saveWrongDataInKeychain(id identifier: Any, service: KeychainService, secretData: Data, objectData: Any) throws {
        var query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrAccount as String: identifier,
                                    kSecAttrService as String: service.rawValue,
                                    kSecAttrAccessGroup as String: service.accessGroup,
                                    kSecValueData as String: secretData]
        query[kSecAttrGeneric as String] = objectData

        switch service.classification {
        case .restricted:
            query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        case .secret:
            query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        case .confidential, .topsecret:
            let access = SecAccessControlCreateWithFlags(nil, // Use the default allocator.
                kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                .userPresence,
                nil) // Ignore any error.
            query[kSecAttrAccessControl as String] = access
        }

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unhandledError(status.message)
        }
    }
}
