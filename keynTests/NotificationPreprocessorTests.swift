import XCTest
import UserNotifications

@testable import keyn
@testable import keynNotificationExtension

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
        let notificationService = NotificationProcessor()
        let enriched = try! notificationService.process(content: content!)

        XCTAssertNil(enriched)
    }
//
//    func testEnrichReturnsNotNil() {
//        guard let sessionID = TestHelper.createSession() else {
//            XCTAssertFalse(true)
//            return
//        }
//
//        let encryptedMessage = TestHelper.encryptAsBrowser("{\"s\":0,\"r\":1,\"b\":54}", sessionID)!
//
//        let content: UNMutableNotificationContent? = UNMutableNotificationContent()
//        content?.userInfo = ["data": encryptedMessage, "sessionID": sessionID]
//        let enriched = NotificationPreprocessor.enrich(notification: content)
//
//        XCTAssertNotNil(enriched)
//    }
//
//    func testEnrichReturnsContentWithSiteID() {
//        guard let sessionID = TestHelper.createSession() else {
//            XCTAssertFalse(true)
//            return
//        }
//
//        let encryptedMessage = TestHelper.encryptAsBrowser("{\"s\":0,\"r\":1,\"b\":54}", sessionID)!
//
//        let content: UNMutableNotificationContent? = UNMutableNotificationContent()
//        content?.userInfo = ["data": encryptedMessage, "sessionID": sessionID]
//        let enriched = NotificationPreprocessor.enrich(notification: content)
//
//        let siteID = enriched?.userInfo["siteID"] as! Int
//        XCTAssertEqual(siteID, 0)
//    }
//
//    func testEnrichReturnsContentWithBrowserTab() {
//        guard let sessionID = TestHelper.createSession() else {
//            XCTAssertFalse(true)
//            return
//        }
//
//        let encryptedMessage = TestHelper.encryptAsBrowser("{\"s\":0,\"r\":1,\"b\":54}", sessionID)!
//
//        let content: UNMutableNotificationContent? = UNMutableNotificationContent()
//        content?.userInfo = ["data": encryptedMessage, "sessionID": sessionID]
//        let enriched = NotificationPreprocessor.enrich(notification: content)
//
//        let browserTab = enriched?.userInfo["browserTab"] as! Int
//        XCTAssertEqual(browserTab, 54)
//    }
//
//    func testEnrichReturnsContentWithRequestType() {
//        guard let sessionID = TestHelper.createSession() else {
//            XCTAssertFalse(true)
//            return
//        }
//
//        let encryptedMessage = TestHelper.encryptAsBrowser("{\"s\":0,\"r\":1,\"b\":54}", sessionID)!
//
//        let content: UNMutableNotificationContent? = UNMutableNotificationContent()
//        content?.userInfo = ["data": encryptedMessage, "sessionID": sessionID]
//        let enriched = NotificationPreprocessor.enrich(notification: content)
//
//        let requestType = enriched?.userInfo["requestType"] as! Int
//        XCTAssertEqual(requestType, 1)
//    }
//
//    func testEnrichReturnsContentWithBody() {
//        guard let sessionID = TestHelper.createSession() else {
//            XCTAssertFalse(true)
//            return
//        }
//
//        let encryptedMessage = TestHelper.encryptAsBrowser("{\"s\":0,\"r\":1,\"b\":54}", sessionID)!
//
//        let content: UNMutableNotificationContent? = UNMutableNotificationContent()
//        content?.userInfo = ["data": encryptedMessage, "sessionID": sessionID]
//        let enriched = NotificationPreprocessor.enrich(notification: content)
//
//        XCTAssertEqual(enriched?.body, "Login request for LinkedIn from browser on OS.")
//    }
//
//    func testEnrichReturnsUnchangedIfuserInfoIsNil() {
//        let content: UNMutableNotificationContent? = UNMutableNotificationContent()
//        let enriched = NotificationPreprocessor.enrich(notification: content)
//
//        XCTAssertEqual(content, enriched)
//    }
//
//    func testEnrichReturnsUnchangedIfuserInfoHasNoData() {
//        let content: UNMutableNotificationContent? = UNMutableNotificationContent()
//        content?.userInfo = ["sessionID": "123"]
//        let enriched = NotificationPreprocessor.enrich(notification: content)
//
//        XCTAssertEqual(content, enriched)
//    }
//
//    func testEnrichReturnsUnchangedIfuserInfoHasNoSessionID() {
//        let content: UNMutableNotificationContent? = UNMutableNotificationContent()
//        content?.userInfo = ["data": "test"]
//        let enriched = NotificationPreprocessor.enrich(notification: content)
//
//        XCTAssertEqual(content, enriched)
//    }
//
//    func testEnrichReturnsUnchangedIfSessionDoesntExist() {
//        let content: UNMutableNotificationContent? = UNMutableNotificationContent()
//        content?.userInfo = ["data": "test", "sessionID": "123"]
//        let enriched = NotificationPreprocessor.enrich(notification: content)
//
//        XCTAssertEqual(content, enriched)
//    }
//
//    func testEnrichReturnsUnchangedIfMessageCannotBeDecrypted() {
//        guard let sessionID = TestHelper.createSession() else {
//            return XCTAssertFalse(true)
//        }
//
//        let encryptedMessage = ".GarblEdMSsaAGe±"
//        let content: UNMutableNotificationContent? = UNMutableNotificationContent()
//        content?.userInfo = ["data": encryptedMessage, "sessionID": sessionID]
//        let enriched = NotificationPreprocessor.enrich(notification: content)
//
//        XCTAssertEqual(content, enriched)
//    }
//
//    func testEnrichReturnsUnchangedIfDataCannotBeParsed() {
//        guard let sessionID = TestHelper.createSession() else {
//            XCTAssertFalse(true)
//            return
//        }
//
//        let encryptedMessage = TestHelper.encryptAsBrowser("oops", sessionID)!
//        let content: UNMutableNotificationContent? = UNMutableNotificationContent()
//        content?.userInfo = ["data": encryptedMessage, "sessionID": sessionID]
//        let enriched = NotificationPreprocessor.enrich(notification: content)
//
//        XCTAssertEqual(content, enriched)
//    }
//
//    func testEnrichReturnsUnchangedIfSiteCannotBeFound() {
//        guard let sessionID = TestHelper.createSession() else {
//            XCTAssertFalse(true)
//            return
//        }
//
//        let encryptedMessage = TestHelper.encryptAsBrowser("1000 42", sessionID)!
//        let content: UNMutableNotificationContent? = UNMutableNotificationContent()
//        content?.userInfo = ["data": encryptedMessage, "sessionID": sessionID]
//        let enriched = NotificationPreprocessor.enrich(notification: content)
//
//        XCTAssertEqual(content, enriched)
//    }

}
