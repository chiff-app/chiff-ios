import XCTest
import UserNotifications

@testable import keyn

class NotificationProcessorTests: XCTestCase {

    var sessionID: String!

    override func setUp() {
        super.setUp()
        TestHelper.setUp()
        TestHelper.createSession()
    }

    override func tearDown() {
        super.tearDown()
        TestHelper.tearDown()
    }

    func testEnrichReturnsNilIfContentIsNil() {
        //        let content: UNMutableNotificationContent? = nil
        //        let notificationService = NotificationProcessor()
        //        let enriched = try! notificationService.process(content: content)
        //
        //        XCTAssertNil(enriched)

    }

    func testProcessDoesNotThrow() {
        let encryptedMessage = TestHelper.encryptAsBrowser("{\"s\":\"\(TestHelper.linkedInPPDHandle)\",\"r\":1,\"b\":54}", TestHelper.sessionID)!

        let content: UNMutableNotificationContent = UNMutableNotificationContent()
        content.userInfo = ["data": encryptedMessage, "sessionID": TestHelper.sessionID]

        XCTAssertNoThrow(try NotificationProcessor.process(content: content))
    }

    func testEnrichReturnsContentWithSiteID() {
        let encryptedMessage = TestHelper.encryptAsBrowser("{\"s\":\"\(TestHelper.linkedInPPDHandle)\",\"r\":1,\"b\":54}", TestHelper.sessionID)!

        let content: UNMutableNotificationContent = UNMutableNotificationContent()
        content.userInfo = ["data": encryptedMessage, "sessionID": TestHelper.sessionID]

        do {
            guard let siteID = try NotificationProcessor.process(content: content).userInfo["siteID"] as? String else {
                XCTFail("Error parsing browserTab as Int")
                return
            }
            XCTAssertEqual(siteID, TestHelper.linkedInPPDHandle)
        } catch {
            XCTFail("Error during processing: \(error)")
        }
    }

    func testEnrichReturnsContentWithBrowserTab() {
        let encryptedMessage = TestHelper.encryptAsBrowser("{\"s\":\"\(TestHelper.linkedInPPDHandle)\",\"r\":1,\"b\":54}", TestHelper.sessionID)!

        let content: UNMutableNotificationContent = UNMutableNotificationContent()
        content.userInfo = ["data": encryptedMessage, "sessionID": TestHelper.sessionID]
        do {
            guard let browserTab = try NotificationProcessor.process(content: content).userInfo["browserTab"] as? Int else {
                XCTFail("Error parsing browserTab as Int")
                return
            }
            XCTAssertEqual(browserTab, 54)
        } catch {
            XCTFail("Error during processing: \(error)")
        }
    }

    func testEnrichReturnsContentWithRequestType() {
        let encryptedMessage = TestHelper.encryptAsBrowser("{\"s\":\"\(TestHelper.linkedInPPDHandle)\",\"r\":1,\"b\":54}", TestHelper.sessionID)!

        let content: UNMutableNotificationContent = UNMutableNotificationContent()
        content.userInfo = ["data": encryptedMessage, "sessionID": TestHelper.sessionID]
        do {
            guard let requestType = try NotificationProcessor.process(content: content).userInfo["requestType"] as? Int else {
                XCTFail("Error parsing browserTab as Int")
                return
            }
            XCTAssertEqual(requestType, 1)
        } catch {
            XCTFail("Error during processing: \(error)")
        }
    }

    func testEnrichReturnsContentWithBody() {
        let encryptedMessage = TestHelper.encryptAsBrowser("{\"s\":\"\(TestHelper.linkedInPPDHandle)\",\"r\":1,\"b\":54}", TestHelper.sessionID)!

        let content: UNMutableNotificationContent = UNMutableNotificationContent()
        content.userInfo = ["data": encryptedMessage, "sessionID": TestHelper.sessionID]
        do {
            let processed = try NotificationProcessor.process(content: content)
            XCTAssertEqual(processed.body, "Unknown on Chrome on MacOS.")
        } catch {
            XCTFail("Error during processing: \(error)")
        }
    }

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
