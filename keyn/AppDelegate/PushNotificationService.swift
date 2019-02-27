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
     * Tells the app that a remote notification arrived that indicates there is data to be fetched.
     * Called when we set "content-available": 1
     * After this the userNotificationCenter function will also be called.
     */
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        completionHandler(UIBackgroundFetchResult.noData)
    }

    /*
     * Called whenever the app is in the foreground and notification comes in.
     */
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let presentationOptions = handleNotification(notification)
        completionHandler(presentationOptions)
    }

    /*
     * Called whenever the app is opened by clicking on a notification.
     */
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let _ = handleNotification(response.notification)
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

    /*
     * Parses the push notification then ends session or presents the requestview.
     *
     * Only one calling function actually uses the returned presentation options.
     */
    private func handleNotification(_ notification: UNNotification) -> UNNotificationPresentationOptions {
        if (notification.request.content.categoryIdentifier == NotificationCategory.KEYN_NOTIFICATION) {
            #warning("TODO: Make alert banner to show user a general keyn message.")
            Logger.shared.debug("TODO: Make alert banner to show user a general keyn message.")
            return [.alert]
        }

        var content: UNNotificationContent = notification.request.content

        if !content.isProcessed() {
            Logger.shared.warning("It seems we need to manually call NotificationProcessor.process().")
            content = reprocess(content: notification.request.content)
        }

        guard let encodedKeynRequest: Data = content.userInfo["keynRequest"] as? Data else {
            Logger.shared.error("Cannot find a KeynRequest in the push notification.")
            return []
        }

        guard let keynRequest = try? PropertyListDecoder().decode(KeynRequest.self, from: encodedKeynRequest) else {
            Logger.shared.error("Cannot decode the KeynRequest sent through a push notification.")
            return []
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
            return [.alert, .sound]
        }

        if notification.date.timeIntervalSinceNow <= -180.0 {
            Logger.shared.warning("Got a notification older than 3 minutes. I will be ignoring it.")
            return []
        }

        if notification.request.content.title == "Error" {
            Logger.shared.warning("iOS notification content parsing failed")
            return []
        }

        DispatchQueue.main.async {
            AuthorizationGuard.shared.launchRequestView(with: keynRequest)
        }

        return [.sound]
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
                let _ = self.handleNotification(notification)
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
