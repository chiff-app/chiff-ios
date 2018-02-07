import XCTest
import UserNotifications

@testable import keyn

class NotificationPreprocessorTests: XCTestCase {

    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
    }

    func completeUserInfo() -> [String: String] {
        return [
            "data": "test",
            "sessionID": "123"
        ]
    }

    func testEnrichReturnsNilIfContentIsNil() {
        let content: UNMutableNotificationContent? = nil
        let enriched = NotificationPreprocessor.enrich(notification: content)
        XCTAssertNil(enriched)
    }

    func testEnrichReturnsNilIfuserInfoDataIsNil() {
        let content: UNMutableNotificationContent? = UNMutableNotificationContent()
        content?.userInfo = completeUserInfo()
        let enriched = NotificationPreprocessor.enrich(notification: content)
        XCTAssertNil(enriched)
    }
}
