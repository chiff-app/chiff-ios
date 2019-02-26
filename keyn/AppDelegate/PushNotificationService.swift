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
    
    private let PASSWORD_CHANGE_CONFIRMATION_POLLING_ATTEMPTS = 3
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        handlePendingNotifications()

        let nc = NotificationCenter.default
        nc.addObserver(forName: NSNotification.Name.passwordChangeConfirmation, object: nil, queue: nil, using: handlePasswordConfirmationNotification)

        return true
    }

    /*
     * This function is called when I DONT KNOW.
     */
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any]) {
        Logger.shared.debug("PushNotificationDebug", userInfo: ["title": userInfo[NotificationContentKey.type] ?? "nada"])
    }

    /*
     * This function is called when I DONT KNOW.
     * Tells the app that a remote notification arrived that indicates there is data to be fetched.
     */
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        Logger.shared.debug("PushNotificationDebug: didReceiveRemoteNotification, fetchCompletionHandler", userInfo: ["title": userInfo[NotificationContentKey.type] ?? "nada"])

//        guard let messageTypeValue = userInfo[NotificationContentKey.type] as? Int, let messageType = KeynMessageType(rawValue: messageTypeValue) else {
//            Logger.shared.warning("Could not parse message from browser (unknown message type).")
//            completionHandler(UIBackgroundFetchResult.noData)
//            return
//        }
//
//        guard let sessionID = userInfo[NotificationContentKey.sessionId] as? String else {
//            Logger.shared.warning("Could not parse sessionID.")
//            completionHandler(UIBackgroundFetchResult.noData)
//            return
//        }
//
//        guard let keynRequest = userInfo["keynRequest"] as? KeynRequest else {
//            Logger.shared.error("Did not receive a (valid) KeynRequest through a push notification.")
//            completionHandler(UIBackgroundFetchResult.noData)
//            return
//        }
//
//        if messageType == .end {
//            do {
//                try Session.get(id: sessionID)?.delete(includingQueue: false)
//            } catch {
//                Logger.shared.error("Could not end session.", error: error, userInfo: nil)
//            }
//        } else {
//            AuthorizationGuard.shared.launchRequestView(with: keynRequest)
//        }

        completionHandler(UIBackgroundFetchResult.noData)
    }

    /*
     * Called when a notification is delivered when Keyn app is open in the foreground.
     */
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let res = handleNotification(notification)

        if (res == "only popup") {
            completionHandler([.alert])
            return
        } else if (res == "session ended") {
            completionHandler([.alert, .sound])
            return
        } else if (res == "request view launched") {
            completionHandler([.sound])
        } else { // res == ""
            completionHandler([])
        }
    }

    /*
     * Called when a user clicks on the notification (or selects an option from it) when the app is in the background.
     */
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let res = handleNotification(response.notification)

        if (res == "only popup") {
            completionHandler()
            return
        } else if (res == "session ended") {
            completionHandler()
            return
        } else if (res == "request view launched") {
            completionHandler()
        } else { // res == ""
            completionHandler()
        }
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        handlePendingNotifications()
    }

    // MARK: - Private

    private func handlePasswordConfirmationNotification(notification: Notification) {
        guard let session = notification.object as? Session else {
            return
        }

        guard session.backgroundTask == UIBackgroundTaskIdentifier.invalid.rawValue else {
            return
        }

        session.backgroundTask = UIApplication.shared.beginBackgroundTask(expirationHandler: {
            let id = UIBackgroundTaskIdentifier(rawValue: session.backgroundTask)
            UIApplication.shared.endBackgroundTask(id)
            session.backgroundTask = UIBackgroundTaskIdentifier.invalid.rawValue
        }).rawValue

        self.pollQueue(attempts: PASSWORD_CHANGE_CONFIRMATION_POLLING_ATTEMPTS, session: session, shortPolling: false, completionHandler: {
            if session.backgroundTask != UIBackgroundTaskIdentifier.invalid.rawValue {
                let id = UIBackgroundTaskIdentifier(rawValue: session.backgroundTask)
                UIApplication.shared.endBackgroundTask(id)
            }
        })
    }

    private func handleNotification(_ notification: UNNotification) -> String {
        if (notification.request.content.categoryIdentifier == NotificationCategory.KEYN_NOTIFICATION) {
            Logger.shared.debug("TODO: Make alert banner to show user a general keyn message.")
            return "only popup"
        }

        var content: UNNotificationContent = notification.request.content

        if !content.isProcessed() {
            print(notification.request.content.userInfo)
            Logger.shared.debug("It seems we need to manually call NotificationProcessor.process().")
            content = reprocess(content: notification.request.content)
        }

        guard let keynRequest = content.userInfo["keynRequest"] as? KeynRequest else {
            Logger.shared.error("Did not receive a (valid) KeynRequest through a push notification.")
            return ""
        }

        if keynRequest.type == .end {
            do {
                if let sessionID = keynRequest.sessionID {
                    try Session.get(id: sessionID)?.delete(includingQueue: false)
                    NotificationCenter.default.post(name: .sessionEnded, object: nil, userInfo: [NotificationContentKey.sessionId: sessionID])
                }
            } catch {
                let error = content.userInfo["error"] as? String
                Logger.shared.error("Could not end session.", error: nil, userInfo: ["error": error as Any])
            }
            return "session ended"
        }

        if notification.date.timeIntervalSinceNow <= -180.0 {
            Logger.shared.warning("Got a notification older than 3 minutes. I will be ignoring it.")
            return ""
        }

        if notification.request.content.title == "Error" {
            Logger.shared.warning("iOS notification content parsing failed")
            return ""
        }

        if !AuthorizationGuard.shared.authorizationInProgress {
            DispatchQueue.main.async {
                AuthorizationGuard.shared.launchRequestView(with: keynRequest)
            }
            return "request view launched"
        }

        return ""
    }

    private func handlePendingNotifications() {
        do {
            for session in try Session.all() {
                self.pollQueue(attempts: 1, session: session, shortPolling: true, completionHandler: nil)
            }
        } catch {
            Logger.shared.error("Could not get sessions.", error: error)
        }

        UNUserNotificationCenter.current().getDeliveredNotifications { (notifications) in
            for notification in notifications {
                let res = self.handleNotification(notification)

                if (res == "only popup") {
                    return
                } else if (res == "session ended") {
                    return
                } else if (res == "request view launched") {
                    //
                } else { // res == ""
                    return
                }
            }
        }
    }

    private func pollQueue(attempts: Int, session: Session, shortPolling: Bool, completionHandler: (() -> Void)?) {
        session.getPasswordChangeConfirmations(shortPolling: shortPolling) { (data, error) in
            if let data = data, let messages = data["messages"] as? [[String:String]], messages.count > 0 {
                for message in messages {
                    guard let body = message[MessageParameter.body] else {
                        Logger.shared.error("Could not parse SQS message. The body is missing.")
                        return
                    }
                    guard let receiptHandle = message[MessageParameter.receiptHandle] else {
                        Logger.shared.error("Could not parse SQS message. The receiptHandle is missing.")
                        return
                    }
                    session.deletePasswordChangeConfirmation(receiptHandle: receiptHandle)
                    do {
                        let keynRequest = try session.decrypt(message: body)
                        if let result = keynRequest.passwordSuccessfullyChanged, let accountId = keynRequest.accountID, keynRequest.type == .acknowledge, result {
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
                Logger.shared.error("Error getting password change confirmation from persistent queue.", error: error)
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
