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

    func testEnrichReturnsEnriched() {
        guard let sessionID = TestHelper.createSession() else {
            XCTAssertFalse(true)
            return
        }

        let encryptedMessage = TestHelper.encryptAsBrowser("{\"s\":0,\"r\":1,\"b\":54}", sessionID)!

        let content: UNMutableNotificationContent? = UNMutableNotificationContent()
        content?.userInfo = ["data": encryptedMessage, "sessionID": sessionID]
        let enriched = NotificationPreprocessor.enrich(notification: content)
        print(enriched?.userInfo)
        XCTAssertNotNil(enriched)
    }

    func testEnrichReturnsUnchangedIfuserInfoIsNil() {
        let content: UNMutableNotificationContent? = UNMutableNotificationContent()
        let enriched = NotificationPreprocessor.enrich(notification: content)

        XCTAssertEqual(content, enriched)
    }

    func testEnrichReturnsUnchangedfuserInfoHasNoData() {
        let content: UNMutableNotificationContent? = UNMutableNotificationContent()
        content?.userInfo = ["sessionID": "123"]
        let enriched = NotificationPreprocessor.enrich(notification: content)

        XCTAssertEqual(content, enriched)
    }

    func testEnrichReturnsUnchangedIfuserInfoHasNoSessionID() {
        let content: UNMutableNotificationContent? = UNMutableNotificationContent()
        content?.userInfo = ["data": "test"]
        let enriched = NotificationPreprocessor.enrich(notification: content)

        XCTAssertEqual(content, enriched)
    }

    func testEnrichReturnsUnchangedIfSessionDoesntExist() {
        let content: UNMutableNotificationContent? = UNMutableNotificationContent()
        content?.userInfo = ["data": "test", "sessionID": "123"]
        let enriched = NotificationPreprocessor.enrich(notification: content)

        XCTAssertEqual(content, enriched)
    }

    func testEnrichReturnsUnchangedIfMessageCannotBeDecrypted() {
        guard let sessionID = TestHelper.createSession() else {
            return XCTAssertFalse(true)
        }

        let encryptedMessage = ".GarblEdMSsaAGe±"
        let content: UNMutableNotificationContent? = UNMutableNotificationContent()
        content?.userInfo = ["data": encryptedMessage, "sessionID": sessionID]
        let enriched = NotificationPreprocessor.enrich(notification: content)

        XCTAssertEqual(content, enriched)
    }

    func testEnrichReturnsUnchangedIfDataCannotBeParsed() {
        guard let sessionID = TestHelper.createSession() else {
            XCTAssertFalse(true)
            return
        }

        let encryptedMessage = TestHelper.encryptAsBrowser("oops", sessionID)!
        let content: UNMutableNotificationContent? = UNMutableNotificationContent()
        content?.userInfo = ["data": encryptedMessage, "sessionID": sessionID]
        let enriched = NotificationPreprocessor.enrich(notification: content)

        XCTAssertEqual(content, enriched)
    }

    func testEnrichReturnsUnchangedIfSiteCannotBeFound() {
        guard let sessionID = TestHelper.createSession() else {
            XCTAssertFalse(true)
            return
        }

        let encryptedMessage = TestHelper.encryptAsBrowser("1000 42", sessionID)!
        let content: UNMutableNotificationContent? = UNMutableNotificationContent()
        content?.userInfo = ["data": encryptedMessage, "sessionID": sessionID]
        let enriched = NotificationPreprocessor.enrich(notification: content)

        XCTAssertEqual(content, enriched)
    }

}
