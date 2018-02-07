import XCTest

@testable import keyn

class SessionTests: XCTestCase {

    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
        TestHelper.deleteSessionKeys()
    }

    // init

    func testInitValidSessionDoesntThrow() {
        XCTAssertNoThrow(
            try Session(sqs: "sqs", browserPublicKey: "YQ", browser: "browser", os: "OS")
        )
    }

    func testInitWithInvalidBrowserPublicKeyThrows() {
        XCTAssertThrowsError(
            try Session(sqs: "sqs", browserPublicKey: "YQ==", browser: "browser", os: "OS")) { error in
                XCTAssertEqual(error as? SessionError, SessionError.invalid)
        }
    }

    func testInitShouldThrowWhenSessionAlreadyPresent() {
        XCTAssertNoThrow(
            try Session(sqs: "sqs", browserPublicKey: "YQ", browser: "browser", os: "OS")
        )
        XCTAssertThrowsError(
            try Session(sqs: "sqs", browserPublicKey: "YQ", browser: "browser", os: "OS")) { error in
                XCTAssertEqual(error as? SessionError, SessionError.exists)
        }
    }

    // delete

    func testDeleteShouldDeleteSession() {

    }

    func testDeleteShouldNotThrowIfBrowserServiceThrows() {

    }

    func testDeleteShouldNotThrowIfAppServiceThrows() {

    }

    // browserPublicKey

    // appPrivateKey

    // decrypt

    // sendCredentials

    // all

    // exists

    // getSession
}
