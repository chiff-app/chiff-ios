/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import Foundation
import UIKit
import UserNotifications

/*
 * Handles push notification that come from outside the app.
 */
class PushNotificationService: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    private let PASSWORD_CONFIRMATION_POLLING_ATTEMPTS = 3
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        handlePendingNotifications()

        let nc = NotificationCenter.default
        nc.addObserver(forName: NSNotification.Name.passwordChangeConfirmation, object: nil, queue: nil, using: handlePasswordConfirmationNotification)

        return true
    }

    // TODO: When does this occur?
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any]) {
        Logger.shared.debug("PushNotificationDebug", userInfo: ["title": userInfo[NotificationContentKey.requestType] ?? "nada"])
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        Logger.shared.debug("PushNotificationDebug", userInfo: ["title": userInfo[NotificationContentKey.requestType] ?? "nada"])

        guard let browserMessageTypeValue = userInfo[NotificationContentKey.requestType] as? Int, let browserMessageType = BrowserMessageType(rawValue: browserMessageTypeValue) else {
            Logger.shared.warning("Could not parse browsermessage.")
            completionHandler(UIBackgroundFetchResult.noData)
            return
        }

        guard let sessionID = userInfo[NotificationContentKey.sessionId] as? String else {
            Logger.shared.warning("Could not parse sessionID.")
            completionHandler(UIBackgroundFetchResult.noData)
            return
        }

        if browserMessageType == .end {
            do {
                try Session.getSession(id: sessionID)?.delete(includingQueue: false)
            } catch {
                Logger.shared.error("Could not end session.", error: error, userInfo: nil)
            }
        } else {
            let _ = handleNotification(userInfo: userInfo, sessionID: sessionID, browserMessageType: browserMessageType)
        }
        completionHandler(UIBackgroundFetchResult.noData)
    }

    // Called when a notification is delivered when Keyn app is opened in foreground.
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        Logger.shared.debug("PushNotificationService:userNotificationCenter(.. willPresent ..)")

        guard notification.request.content.categoryIdentifier != NotificationCategory.KEYN_NOTIFICATION else {
            Logger.shared.debug("TODO: Make alert banner")
            completionHandler([.alert])
            return
        }

        // DEBUG: Push notifications
        var originalBody: String?
        var content: UNNotificationContent
        var reprocessed = false
        var error: String?
        if notification.request.content.userInfo[NotificationContentKey.requestType] != nil {
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

        guard let browserMessageTypeValue = content.userInfo[NotificationContentKey.requestType] as? Int, let browserMessageType = BrowserMessageType(rawValue: browserMessageTypeValue) else {
            Logger.shared.warning("Could not parse browsermessage.")
            completionHandler([])
            return
        }

        guard let sessionID = content.userInfo[NotificationContentKey.sessionId] as? String else {
            Logger.shared.warning("Could not parse sessionID.")
            completionHandler([])
            return
        }
        if browserMessageType == .end {
            do {
                try Session.getSession(id: sessionID)?.delete(includingQueue: false)
                let nc = NotificationCenter.default
                nc.post(name: .sessionEnded, object: nil, userInfo: [NotificationContentKey.sessionId: sessionID])
            } catch {
                Logger.shared.error("Could not end session.", error: error, userInfo: nil)
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

        guard response.notification.request.content.categoryIdentifier != NotificationCategory.KEYN_NOTIFICATION else {
            Logger.shared.debug("TODO: Make alert banner")
            completionHandler()
            return
        }

        // DEBUG: Push notifications
        var originalBody: String?
        var content: UNNotificationContent
        var reprocessed = false
        var error: String?
        if response.notification.request.content.userInfo[NotificationContentKey.requestType] != nil {
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

        guard let browserMessageTypeValue = content.userInfo[NotificationContentKey.requestType] as? Int, let browserMessageType = BrowserMessageType(rawValue: browserMessageTypeValue) else {
            Logger.shared.warning("Could not parse browsermessage.")
            completionHandler()
            return
        }

        guard let sessionID = content.userInfo[NotificationContentKey.sessionId] as? String else {
            Logger.shared.warning("Could not parse sessionID.")
            completionHandler()
            return
        }

        if browserMessageType == .end {
            do {
                try Session.getSession(id: sessionID)?.delete(includingQueue: false)
            } catch {
                Logger.shared.error("Could not end session.", error: error, userInfo: nil)
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

        guard session.backgroundTask == UIBackgroundTaskIdentifier.invalid else {
            return
        }

        session.backgroundTask = UIApplication.shared.beginBackgroundTask(expirationHandler: {
            UIApplication.shared.endBackgroundTask(session.backgroundTask)
            UIApplication.shared.endBackgroundTask(session.backgroundTask)
            session.backgroundTask = UIBackgroundTaskIdentifier.invalid
        })

        self.pollQueue(attempts: PASSWORD_CONFIRMATION_POLLING_ATTEMPTS, session: session, shortPolling: false, completionHandler: {
            if session.backgroundTask != UIBackgroundTaskIdentifier.invalid {
                UIApplication.shared.endBackgroundTask(session.backgroundTask)
            }
        })
    }

    private func handleNotification(userInfo: [AnyHashable: Any], sessionID: String, browserMessageType: BrowserMessageType) -> Bool {
        guard let siteID = userInfo[NotificationContentKey.siteId] as? String else {
            Logger.shared.warning("Wrong siteID type.")
            return false
        }
        guard let siteName = userInfo[NotificationContentKey.siteName] as? String else {
            Logger.shared.warning("Wrong siteName type.")
            return false
        }
        guard let browserTab = userInfo[NotificationContentKey.browserTab] as? Int else {
            Logger.shared.warning("Wrong browserTab type.")
            return false
        }
        guard let currentPassword = userInfo[NotificationContentKey.password] as? String? else {
            Logger.shared.warning("Wrong currentPassword type.")
            return false
        }
        guard let username = userInfo[NotificationContentKey.username] as? String? else {
            Logger.shared.warning("Wrong username type.")
            return false
        }

        AuthorizationGuard.shared.launchRequestView(with: PushNotification(sessionID: sessionID, siteID: siteID, siteName: siteName, browserTab: browserTab, currentPassword: currentPassword, requestType: browserMessageType, username: username))

        return true
    }

    private func handlePendingNotifications() {
        do {
            for session in try Session.all() {
                self.pollQueue(attempts: 1, session: session, shortPolling: true, completionHandler: nil)
            }
        } catch {
            Logger.shared.error("Could not get sessions.", error: error)
        }

        let center = UNUserNotificationCenter.current()
        center.getDeliveredNotifications { (notifications) in
            for notification in notifications {

                guard notification.request.content.categoryIdentifier != NotificationCategory.KEYN_NOTIFICATION else {
                    Logger.shared.debug("TODO: Make alert banner")
                    return
                }

                // DEBUG: Push notifications
                var originalBody: String?
                var content: UNNotificationContent
                var reprocessed = false
                var error: String?
                if notification.request.content.userInfo[NotificationContentKey.requestType] != nil {
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

                if let browserMessageTypeValue = content.userInfo[NotificationContentKey.requestType] as? Int,
                    let browserMessageType = BrowserMessageType(rawValue: browserMessageTypeValue),
                    let sessionID = content.userInfo[NotificationContentKey.sessionId] as? String
                {
                    if browserMessageType == .end {
                        do {
                            try Session.getSession(id: sessionID)?.delete(includingQueue: false)
                        } catch {
                            Logger.shared.error("Could not end session.", error: error)
                        }

                    } else if notification.date.timeIntervalSinceNow > -180.0  {

                        if content.title == "Error" {
                            Logger.shared.warning("iOS notification content parsing failed")
                        }

                        guard let siteID = content.userInfo[NotificationContentKey.siteId] as? String else {
                            Logger.shared.warning("Wrong siteID type.")
                            return
                        }
                        guard let siteName = content.userInfo[NotificationContentKey.siteName] as? String else {
                            Logger.shared.warning("Wrong siteName type.")
                            return
                        }
                        guard let browserTab = content.userInfo[NotificationContentKey.browserTab] as? Int else {
                            Logger.shared.warning("Wrong browserTab type.")
                            return
                        }
                        guard let currentPassword = content.userInfo[NotificationContentKey.password] as? String? else {
                            Logger.shared.warning("Wrong currentPassword type.")
                            return
                        }
                        guard let username = content.userInfo[NotificationContentKey.username] as? String? else {
                            Logger.shared.warning("Wrong username type.")
                            return
                        }

                        DispatchQueue.main.async {
                            if !AuthorizationGuard.shared.authorizationInProgress {
                                AuthorizationGuard.shared.launchRequestView(with: PushNotification(sessionID: sessionID, siteID: siteID, siteName: siteName, browserTab: browserTab, currentPassword: currentPassword, requestType: browserMessageType, username: username))
                            }
                        }
                    }
                }
            }
        }
    }

    private func pollQueue(attempts: Int, session: Session, shortPolling: Bool, completionHandler: (() -> Void)?) {

        session.getChangeConfirmations(shortPolling: shortPolling) { (data, error) in
            if let data = data, let messages = data["messages"] as? [[String:String]], messages.count > 0 {
                for message in messages {
                    guard let body = message[MessageParameter.body] else {
                        Logger.shared.error("Could not parse SQS message body.")
                        return
                    }
                    guard let receiptHandle = message[MessageParameter.receiptHandle] else {
                        Logger.shared.error("Could not parse SQS message body.")
                        return
                    }
                    guard let typeString = message[MessageParameter.type], let type = Int(typeString) else {
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
                            try account?.updatePasswordAfterConfirmation()
                        }
                    } catch {
                        Logger.shared.warning("Could not change password", error: error, userInfo: nil)
                    }
                    if let handler = completionHandler {
                        handler()
                    }
                }
            } else if let error = error {
                Logger.shared.error("Error getting change confirmations", error: error)
            } else {
                if (attempts > 1) {
                    self.pollQueue(attempts: attempts - 1, session: session, shortPolling: shortPolling, completionHandler: completionHandler)
                } else if let handler = completionHandler {
                    handler()
                }
            }
        }
    }

    // DEBUG
    private func reprocess(content: UNNotificationContent) -> UNNotificationContent {
        guard let mutableContent = (content.mutableCopy() as? UNMutableNotificationContent) else {
            return content
        }
        do {
            return try NotificationProcessor.process(content: mutableContent)
        } catch {
            Logger.shared.debug("Error reprocessing data", error: error)
        }

        return content
    }
}
