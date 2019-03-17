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
        nc.addObserver(forName: .passwordChangeConfirmation, object: nil, queue: nil, using: handlePasswordConfirmationNotification)
        nc.addObserver(forName: .accountsLoaded, object: nil, queue: nil, using: checkPersistentQueue)

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
                    try Session.get(id: sessionID)?.delete(notifyExtension: false)
                    NotificationCenter.default.post(name: .sessionEnded, object: nil, userInfo: [NotificationContentKey.sessionId: sessionID])
                }
            } catch {
                let error = content.userInfo["error"] as? String
                Logger.shared.error("Could not end session.", error: nil, userInfo: ["error": error as Any])
            }
            return [.alert, .sound]
        }

        guard notification.request.content.title != "Error" else {
            Logger.shared.warning("iOS notification content parsing failed")
            return []
        }

        guard Date(timeIntervalSince1970: keynRequest.sentTimestamp / 1000).timeIntervalSinceNow > -180 else {
            Logger.shared.warning("Got a notification older than 3 minutes. I will be ignoring it.")
            DispatchQueue.main.async {
                AuthorizationGuard.launchExpiredRequestView(with: keynRequest)
            }
            return []
        }

        DispatchQueue.main.async {
            AuthorizationGuard.launchRequestView(with: keynRequest)
        }

        return [.sound]
    }

    private func handlePendingNotifications() {
        UNUserNotificationCenter.current().getDeliveredNotifications { (notifications) in
            for notification in notifications {
                let _ = self.handleNotification(notification)
            }
        }
    }

    @objc func checkPersistentQueue(notification: Notification) {
        do {
            for session in try Session.all() {
                self.pollQueue(attempts: 1, session: session, shortPolling: true, completionHandler: nil)
            }
        } catch {
            Logger.shared.error("Could not get sessions.", error: error)
        }
    }

    private func pollQueue(attempts: Int, session: Session, shortPolling: Bool, completionHandler: (() -> Void)?) {
        session.getPersistentQueueMessages(shortPolling: shortPolling) { (messages, error) in
            if let error = error {
                Logger.shared.error("Error getting password change confirmation from persistent queue.", error: error)
                return
            }
            do {
                guard let messages = messages, !messages.isEmpty else {
                    if (attempts > 1) {
                        self.pollQueue(attempts: attempts - 1, session: session, shortPolling: shortPolling, completionHandler: completionHandler)
                    } else if let handler = completionHandler {
                        handler()
                    }
                    return
                }
                try messages.forEach({ try self.handlePersistenQueueMessage(keynMessage: $0, session: session) })
            } catch {
                Logger.shared.warning("Could not get account list", error: error, userInfo: nil)
            }
            if let handler = completionHandler {
                handler()
            }
        }
    }

    private func handlePersistenQueueMessage(keynMessage: KeynPersistentQueueMessage, session: Session) throws {
        guard let accountId = keynMessage.accountID, let receiptHandle = keynMessage.receiptHandle else  {
            throw CodingError.missingData
        }
        Account.get(accountID: accountId, reason: "Update password", type: .never) { (account, context, error) in
            do {
                var mutableAccount = account
                if let error = error {
                    throw error
                }
                guard mutableAccount != nil else {
                    throw AccountError.accountsNotLoaded
                }
                switch keynMessage.type {
                case .confirm:
                    guard let result = keynMessage.passwordSuccessfullyChanged else {
                        throw CodingError.missingData
                    }
                    if result {
                        try mutableAccount!.updatePasswordAfterConfirmation()
                    }
                case .preferences:
                    try mutableAccount!.update(username: nil, password: nil, siteName: nil, url: nil, askToLogin: keynMessage.askToLogin, askToChange: keynMessage.askToChange, context: context)
                default:
                    Logger.shared.debug("Unknown message type received", userInfo: ["messageType": keynMessage.type.rawValue ])
                }
                session.deleteFromPersistentQueue(receiptHandle: receiptHandle)
            } catch {
                Logger.shared.error("Error handling persistent queue message", error: error)
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
