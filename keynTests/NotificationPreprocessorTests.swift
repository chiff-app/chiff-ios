import XCTest
import UserNotifications

@testable import keyn

class NotificationPreprocessorTests: XCTestCase {

    override func setUp() {
        TestHelper.deleteSessionKeys()
        // TODO
        // Set up example site. Actually this is now still
        // already done because we already use sample data.
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
        TestHelper.deleteSessionKeys()
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
        guard let sessionID = TestHelper.createSession() else {
            XCTAssertFalse(true)
            return
        }

        let encryptedMessage =  TestHelper.fakeBrowserEncrypt("0 42", sessionID)!

        let content: UNMutableNotificationContent? = UNMutableNotificationContent()
        content?.userInfo = ["data": encryptedMessage, "sessionID": sessionID]
        let enriched = NotificationPreprocessor.enrich(notification: content)

        XCTAssertNotNil(enriched)
    }

}
