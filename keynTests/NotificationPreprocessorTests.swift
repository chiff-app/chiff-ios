import XCTest
import UserNotifications

@testable import keyn

class NotificationPreprocessorTests: XCTestCase {

    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
        TestHelper.deleteSessionKeys()
    }

    private func createSession() -> String? {
        do {
            let session = try Session(sqs: "sqs", browserPublicKey: "YQ", browser: "browser", os: "OS")
            return session.id
        } catch {
            print("Cannot create session, tests will fail")
        }
        return nil
    }

    private func fakeBrowserEncrypt(_ message: String, _ sessionID: String) -> Data? {
        do {
            let session = try Session.getSession(id: sessionID)
            let cipherText = try Crypto.sharedInstance.encrypt(message.data(using: .utf8)!, pubKey: (session?.appPublicKey())!)
            return cipherText
        } catch {
            print("Cannot fake browser encryption, tests will fail")
        }
        return nil
    }

    func testEnrichReturnsNilIfContentIsNil() {
        let content: UNMutableNotificationContent? = nil
        let enriched = NotificationPreprocessor.enrich(notification: content)
        XCTAssertNil(enriched)
    }

    func testEnrichReturnsNilIfuserInfoIsNil() {
        let content: UNMutableNotificationContent? = UNMutableNotificationContent()
        let enriched = NotificationPreprocessor.enrich(notification: content)
        XCTAssertNil(enriched)
    }

    func testEnrichReturnsNilIfuserInfoHasNoData() {
        let content: UNMutableNotificationContent? = UNMutableNotificationContent()
        content?.userInfo = ["sessionID": "123"]
        let enriched = NotificationPreprocessor.enrich(notification: content)
        XCTAssertNil(enriched)
    }

    func testEnrichReturnsNilIfuserInfoHasNoSessionID() {
        let content: UNMutableNotificationContent? = UNMutableNotificationContent()
        content?.userInfo = ["data": "test"]
        let enriched = NotificationPreprocessor.enrich(notification: content)
        XCTAssertNil(enriched)
    }

    func testEnrichReturnsNilIfSessionDoesntExist() {
        let content: UNMutableNotificationContent? = UNMutableNotificationContent()
        content?.userInfo = ["data": "test", "sessionID": "123"]
        let enriched = NotificationPreprocessor.enrich(notification: content)
        XCTAssertNil(enriched)
    }

    func testEnrichReturnsEnriched() {
        guard let sessionID = createSession() else {
            XCTAssertFalse(true)
            return
        }

        let encryptedMessage = fakeBrowserEncrypt("data", sessionID)
        let content: UNMutableNotificationContent? = UNMutableNotificationContent()
        content?.userInfo = ["data": encryptedMessage, "sessionID": sessionID]
        let enriched = NotificationPreprocessor.enrich(notification: content)
        XCTAssertNotNil(enriched)
    }

}
