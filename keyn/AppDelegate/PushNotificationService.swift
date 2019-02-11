/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import Foundation
import JustLog
import UIKit
import UserNotifications

/*
 * Handles push notification that come from outside the app.
 */
class PushNotificationService: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        handlePendingNotifications()

        let nc = NotificationCenter.default
        nc.addObserver(forName: NSNotification.Name.passwordChangeConfirmation, object: nil, queue: nil, using: handlePasswordConfirmationNotification)

        return true
    }

    // TODO: When does this occur?
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any]) {
        Logger.shared.debug("PushNotificationDebug", userInfo: ["title": userInfo["requestType"] ?? "nada"])
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        Logger.shared.debug("PushNotificationDebug", userInfo: ["title": userInfo["requestType"] ?? "nada"])

        guard let browserMessageTypeValue = userInfo["requestType"] as? Int, let browserMessageType = BrowserMessageType(rawValue: browserMessageTypeValue) else {
            Logger.shared.warning("Could not parse browsermessage.")
            completionHandler(UIBackgroundFetchResult.noData)
            return
        }

        guard let sessionID = userInfo["sessionID"] as? String else {
            Logger.shared.warning("Could not parse sessionID.")
            completionHandler(UIBackgroundFetchResult.noData)
            return
        }

        if browserMessageType == .end {
            do {
                try Session.getSession(id: sessionID)?.delete(includingQueue: false)
            } catch {
                Logger.shared.error("Could not end session.", error: error as NSError, userInfo: nil)
            }
        } else {
            let _ = handleNotification(userInfo: userInfo, sessionID: sessionID, browserMessageType: browserMessageType)
        }
        completionHandler(UIBackgroundFetchResult.noData)
    }

    // Called when a notification is delivered when Keyn app is opened in foreground.
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        Logger.shared.debug("PushNotificationService:userNotificationCenter(.. willPresent ..)")

        guard notification.request.content.categoryIdentifier != "KEYN_NOTIFICATION" else {
            Logger.shared.debug("TODO: Make alert banner")
            completionHandler([.alert])
            return
        }

        // DEBUG: Push notifications
        var originalBody: String?
        var content: UNNotificationContent
        var reprocessed = false
        var error: String?
        if notification.request.content.userInfo["requestType"] != nil {
            content = notification.request.content
            error = content.userInfo["error"] as? String
        } else {
            originalBody = notification.request.content.body
            content = reprocess(content: notification.request.content)
            error = content.userInfo["error"] as? String
            reprocessed = true
        }
        var userInfo: [String: Any] = [
            "body": content.body,
            "reprocessed": reprocessed
        ]
        if let error = error {
            userInfo["error"] = error
        }
        if let originalBody = originalBody {
            userInfo["originalBody"] = originalBody
        }
        Logger.shared.debug("PushNotificationDebug", userInfo: userInfo)

        guard let browserMessageTypeValue = content.userInfo["requestType"] as? Int, let browserMessageType = BrowserMessageType(rawValue: browserMessageTypeValue) else {
            Logger.shared.warning("Could not parse browsermessage.")
            completionHandler([])
            return
        }

        guard let sessionID = content.userInfo["sessionID"] as? String else {
            Logger.shared.warning("Could not parse sessionID.")
            completionHandler([])
            return
        }
        if browserMessageType == .end {
            do {
                try Session.getSession(id: sessionID)?.delete(includingQueue: false)
                let nc = NotificationCenter.default
                nc.post(name: .sessionEnded, object: nil, userInfo: ["sessionID": sessionID])
            } catch {
                Logger.shared.error("Could not end session.", error: error as NSError, userInfo: nil)
            }
            completionHandler([.alert, .sound])
        } else {
            if handleNotification(userInfo: content.userInfo, sessionID: sessionID, browserMessageType: browserMessageType) {
                completionHandler([.sound])
            } else {
                completionHandler([])
            }
        }
    }

    // Called when a user selects an option directly from the notification.
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        Logger.shared.debug("PushNotificationService:userNotificationCenter(.. withCompletionHandler ..)")

        // TODO: Find out why we cannot pass RequestType in userInfo..

        guard response.notification.request.content.categoryIdentifier != "KEYN_NOTIFICATION" else {
            Logger.shared.debug("TODO: Make alert banner")
            completionHandler()
            return
        }

        // DEBUG: Push notifications
        var originalBody: String?
        var content: UNNotificationContent
        var reprocessed = false
        var error: String?
        if response.notification.request.content.userInfo["requestType"] != nil {
            content = response.notification.request.content
            error = content.userInfo["error"] as? String
        } else {
            originalBody = response.notification.request.content.body
            content = reprocess(content: response.notification.request.content)
            error = content.userInfo["error"] as? String
            reprocessed = true
        }
        var userInfo: [String: Any] = [
            "body": content.body,
            "reprocessed": reprocessed
        ]
        if let error = error {
            userInfo["error"] = error
        }
        if let originalBody = originalBody {
            userInfo["originalBody"] = originalBody
        }
        Logger.shared.debug("PushNotificationDebug", userInfo: userInfo)

        guard let browserMessageTypeValue = content.userInfo["requestType"] as? Int, let browserMessageType = BrowserMessageType(rawValue: browserMessageTypeValue) else {
            Logger.shared.warning("Could not parse browsermessage.")
            completionHandler()
            return
        }

        guard let sessionID = content.userInfo["sessionID"] as? String else {
            Logger.shared.warning("Could not parse sessionID.")
            completionHandler()
            return
        }

        if browserMessageType == .end {
            do {
                try Session.getSession(id: sessionID)?.delete(includingQueue: false)
            } catch {
                Logger.shared.error("Could not end session.", error: error as NSError, userInfo: nil)
            }
        } else {
            let _ = handleNotification(userInfo: content.userInfo, sessionID: sessionID, browserMessageType: browserMessageType)
        }
        completionHandler()
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        handlePendingNotifications()
    }

    // MARK: - Private

    private func handlePasswordConfirmationNotification(notification: Notification) {
        guard let session = notification.object as? Session else {
            return
        }

        guard session.backgroundTask == UIBackgroundTaskInvalid else {
            return
        }

        session.backgroundTask = UIApplication.shared.beginBackgroundTask(expirationHandler: {
            UIApplication.shared.endBackgroundTask(session.backgroundTask)
            session.backgroundTask = UIBackgroundTaskInvalid
        })

        self.pollQueue(attempts: 3, session: session, shortPolling: false, completionHandler: {
            if session.backgroundTask != UIBackgroundTaskInvalid {
                UIApplication.shared.endBackgroundTask(session.backgroundTask)
            }
        })
    }

    private func handleNotification(userInfo: [AnyHashable: Any], sessionID: String, browserMessageType: BrowserMessageType) -> Bool {
        guard let siteID = userInfo["siteID"] as? String else {
            Logger.shared.warning("Wrong siteID type.")
            return false
        }
        guard let siteName = userInfo["siteName"] as? String else {
            Logger.shared.warning("Wrong siteName type.")
            return false
        }
        guard let browserTab = userInfo["browserTab"] as? Int else {
            Logger.shared.warning("Wrong browserTab type.")
            return false
        }
        guard let currentPassword = userInfo["password"] as? String? else {
            Logger.shared.warning("Wrong currentPassword type.")
            return false
        }
        guard let username = userInfo["username"] as? String? else {
            Logger.shared.warning("Wrong username type.")
            return false
        }

        AuthenticationGuard.shared.launchRequestView(with: PushNotification(sessionID: sessionID, siteID: siteID, siteName: siteName, browserTab: browserTab, currentPassword: currentPassword, requestType: browserMessageType, username: username))

        return true
    }

    private func handlePendingNotifications() {
        do {
            if let sessions = try Session.all() {
                for session in sessions {
                    self.pollQueue(attempts: 1, session: session, shortPolling: true, completionHandler: nil)
                }
            }
        } catch {
            Logger.shared.error("Could not get sessions.", error: error as NSError)
        }

        let center = UNUserNotificationCenter.current()
        center.getDeliveredNotifications { (notifications) in
            for notification in notifications {

                guard notification.request.content.categoryIdentifier != "KEYN_NOTIFICATION" else {
                    Logger.shared.debug("TODO: Make alert banner")
                    return
                }

                // DEBUG: Push notifications
                var originalBody: String?
                var content: UNNotificationContent
                var reprocessed = false
                var error: String?
                if notification.request.content.userInfo["requestType"] != nil {
                    content = notification.request.content
                    error = content.userInfo["error"] as? String
                } else {
                    originalBody = notification.request.content.body
                    content = self.reprocess(content: notification.request.content)
                    error = content.userInfo["error"] as? String
                    reprocessed = true
                }
                var userInfo: [String: Any] = [
                    "body": content.body,
                    "reprocessed": reprocessed
                ]
                if let error = error {
                    userInfo["error"] = error
                }
                if let originalBody = originalBody {
                    userInfo["originalBody"] = originalBody
                }
                Logger.shared.debug("PushNotificationDebug", userInfo: userInfo)

                if let browserMessageTypeValue = content.userInfo["requestType"] as? Int,
                    let browserMessageType = BrowserMessageType(rawValue: browserMessageTypeValue),
                    let sessionID = content.userInfo["sessionID"] as? String
                {
                    if browserMessageType == .end {
                        do {
                            try Session.getSession(id: sessionID)?.delete(includingQueue: false)
                        } catch {
                            Logger.shared.error("Could not end session.", error: error as NSError)
                        }

                    } else if notification.date.timeIntervalSinceNow > -180.0  {

                        if content.title == "Error" {
                            Logger.shared.warning("iOS notification content parsing failed")
                        }

                        guard let siteID = content.userInfo["siteID"] as? String else {
                            Logger.shared.warning("Wrong siteID type.")
                            return
                        }
                        guard let siteName = content.userInfo["siteName"] as? String else {
                            Logger.shared.warning("Wrong siteName type.")
                            return
                        }
                        guard let browserTab = content.userInfo["browserTab"] as? Int else {
                            Logger.shared.warning("Wrong browserTab type.")
                            return
                        }
                        guard let currentPassword = content.userInfo["password"] as? String? else {
                            Logger.shared.warning("Wrong currentPassword type.")
                            return
                        }
                        guard let username = content.userInfo["username"] as? String? else {
                            Logger.shared.warning("Wrong username type.")
                            return
                        }

                        DispatchQueue.main.async {
                            if !AuthenticationGuard.shared.authorizationInProgress {
                                AuthenticationGuard.shared.launchRequestView(with: PushNotification(sessionID: sessionID, siteID: siteID, siteName: siteName, browserTab: browserTab, currentPassword: currentPassword, requestType: browserMessageType, username: username))
                            }
                        }
                    }
                }
            }
        }
    }

    private func pollQueue(attempts: Int, session: Session, shortPolling: Bool, completionHandler: (() -> Void)?) {
        do {
            try session.getChangeConfirmations(shortPolling: shortPolling) { (data) in
                if let data = data, let messages = data["messages"] as? [[String:String]], messages.count > 0 {
                    for message in messages {
                        guard let body = message["body"] else {
                            Logger.shared.error("Could not parse SQS message body.")
                            return
                        }
                        guard let receiptHandle = message["receiptHandle"] else {
                            Logger.shared.error("Could not parse SQS message body.")
                            return
                        }
                        guard let typeString = message["type"], let type = Int(typeString) else {
                            Logger.shared.error("Could not parse SQS message body.")
                            return
                        }
                        guard type == BrowserMessageType.acknowledge.rawValue else {
                            Logger.shared.error("Wrong message type.", userInfo: ["type": type])
                            return
                        }
                        session.deleteChangeConfirmation(receiptHandle: receiptHandle)

                        do {
                            let browserMessage: BrowserMessage = try session.decrypt(message: body)
                            if let result = browserMessage.v, let accountId = browserMessage.a, browserMessage.r == .acknowledge, result {
                                var account = try Account.get(accountID: accountId)
                                try account?.updatePassword(offset: nil)
                            }
                        } catch {
                            Logger.shared.warning("Could not change password", error: error as NSError, userInfo: nil)
                        }
                        if let handler = completionHandler {
                            handler()
                        }
                    }
                } else {
                    if (attempts > 1) {
                        self.pollQueue(attempts: attempts - 1, session: session, shortPolling: shortPolling, completionHandler: completionHandler)
                    } else if let handler = completionHandler {
                        handler()
                    }
                }
            }
        } catch {
            Logger.shared.error("Error getting change confirmations")
        }
    }

    // DEBUG
    private func reprocess(content: UNNotificationContent) -> UNNotificationContent {
        guard let mutableContent = (content.mutableCopy() as? UNMutableNotificationContent) else {
            return content
        }
        do {
            return try NotificationProcessor.process(content: mutableContent)
        } catch NotificationExtensionError.Decryption {
            Logger.shared.debug("Decryption error")
        } catch NotificationExtensionError.Session {
            Logger.shared.debug("Session error")
        } catch NotificationExtensionError.StringCast(let type) {
            Logger.shared.debug("Stringcast error: \(type)")
        } catch {
            Logger.shared.debug("Other error", error: error as NSError)
        }

        return content
    }
}