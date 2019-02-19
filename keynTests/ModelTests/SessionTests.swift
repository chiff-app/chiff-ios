/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import XCTest

@testable import keyn

class SessionTests: XCTestCase {
    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
        TestHelper.tearDown()
    }

    // init

    func testInitValidSessionDoesntThrow() {
        let pairingQueuePrivKey = "q9ZJ9pCc6rBRCLkeujpGUzNNI0lzXnBVXKt4PYspOjE" // MesssageQueuePubKey: GdfCq4cmtUGqRVQUbpjEjOX4a4towe0t5LtV5FWyuYw. Queue is created for testing.
        let pubKey = "97prXmJaSDLrNlt4tljlgaih6OJ-IBW6r6uknz7X-Tk"
        XCTAssertThrowsError(
        try Session.initiate(pairingQueuePrivKey: pairingQueuePrivKey, browserPubKey: pubKey, browser: "Chrome", os: "MacOS")) { error in
            XCTAssertEqual(error as? SessionError, SessionError.noEndpoint)
        }
    }

    func testInitWithInvalidBrowserPublicKeyThrows() {
        let pairingQueuePrivKey = "6OciTGA2VLCSOTmQyKf8HLd_JXFCtgpBUy6YT2DcEvE"
        let pubKey = "joe"//"BdPWy3VOU1JwrNZpbLv_h88DRc0g1BZ_IMTbgyYXEmi"
        XCTAssertThrowsError(
        try Session.initiate(pairingQueuePrivKey: pairingQueuePrivKey, browserPubKey: pubKey, browser: "Chrome", os: "MacOS")) { error in
            print(error)
        }
    }

    func testInitShouldThrowWhenSessionAlreadyPresent() {
        let pairingQueuePrivKey = "v39jwPlUChbQi9NNNyriRxApHfdciCvmVdJSEuwiu3E"
        let pubKey = "fEcOKBCrOXBus1lmfoemGcLSX-TwePKZWZ6BIWAT1Xc"
        XCTAssertThrowsError(
        try Session.initiate(pairingQueuePrivKey: pairingQueuePrivKey, browserPubKey: pubKey, browser: "Chrome", os: "MacOS")) { error in
            XCTAssertEqual(error as? SessionError, SessionError.noEndpoint)
        }
        XCTAssertThrowsError(
        try Session.initiate(pairingQueuePrivKey: pairingQueuePrivKey, browserPubKey: pubKey, browser: "Chrome", os: "MacOS")) { error in
            XCTAssertEqual(error as? SessionError, SessionError.exists)
        }
    }

    // delete

    func testDeleteShouldDeleteSession() {
//        let sessionID = try? TestHelper.createSession()
//        do {
//            let sessionID = try TestHelper.createSession()
//            let session = try Session.getSession(id: sessionID)
//            XCTAssertNotNil(session)
//            try session!.delete(includingQueue: false)
//            XCTAssertNil(try Session.getSession(id: sessionID))
//        } catch {
//            XCTFail("An error occured: \(error)")
//        }
        
    }

    func testDeleteShouldNotThrowIfBrowserServiceThrows() {
        
    }

    func testDeleteShouldNotThrowIfAppServiceThrows() {
        
    }

    // browserPublicKey
    
    func testBrowserPublicKey() {
        
    }

    // appPrivateKey
    
    func testAppPrivateKey() {
        
    }
    
    func testAppPublicKey() {
        
    }

    // decrypt
    
    func testDecrypt() {
        
    }
    
    // sendCredentials
    
    func testAcknowledgeDoesntThrow() {
        
    }
    
    func testSendCredentialsDoesntThrow() {
        
    }
    
    func testGetChangeConfirmation() {
        
    }
    
    func testDeleteChangeConfirmation() {
        
    }
    
    func testAll() {
        
    }
    
    func testExists() {
        
    }
    
    func testDeleteAll() {
        
    }
}
