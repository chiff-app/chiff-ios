import XCTest
@testable import keyn

class SessionTests: XCTestCase {

    private func deleteSessionKeys() {
        // Remove passwords
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: "io.keyn.session.browser"]

        // Try to delete the seed if it exists.
        let status = SecItemDelete(query as CFDictionary)

        if status == errSecItemNotFound { print("No browser sessions found") } else {
            print(status)
        }

        // Remove passwords
        let query2: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                     kSecAttrService as String: "io.keyn.session.app"]

        // Try to delete the seed if it exists.
        let status2 = SecItemDelete(query2 as CFDictionary)

        if status2 == errSecItemNotFound { print("No own sessions keys found") } else {
            print(status2)
        }
    }

    override func setUp() {
        deleteSessionKeys()
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
        deleteSessionKeys()
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
                XCTAssertEqual(error as? SessionError, SessionError.invalidPubkey)
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

}
