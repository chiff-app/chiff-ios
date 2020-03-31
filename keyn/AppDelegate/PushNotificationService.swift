/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import Foundation
import UIKit
import UserNotifications
import LocalAuthentication
import PromiseKit

/*
 * Handles push notification that come from outside the app.
 */
class PushNotificationService: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    private let PASSWORD_CHANGE_CONFIRMATION_POLLING_ATTEMPTS = 3
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        handlePendingNotifications()

        let nc = NotificationCenter.default
        nc.addObserver(forName: .passwordChangeConfirmation, object: nil, queue: nil, using: waitForPasswordChangeConfirmation)
        nc.addObserver(forName: .accountsLoaded, object: nil, queue: nil, using: checkPersistentQueue)

        return true
    }

    /*
     * Tells the app that a remote notification arrived that indicates there is data to be fetched.
     * Called when we set "content-available": 1
     * After this the userNotificationCenter function will also be called.
     */
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        guard let aps = userInfo["aps"] as? [AnyHashable : Any], let category = aps["category"] as? String, category == NotificationCategory.SYNC else {
                completionHandler(.noData)
            return
        }
        do {
            guard let accounts = userInfo["accounts"] as? Bool, let sessionPubKeys = userInfo["sessions"] as? [String] else {
                completionHandler(.failed)
                return
            }
            switch category {
            case NotificationCategory.SYNC:
                var promises: [Promise<Void>] = [TeamSession.sync(pushed: true, logo: true, backup: false, pubKeys: sessionPubKeys)]
                if accounts {
                    promises.append(UserAccount.sync(context: nil))
                }
                firstly {
                    when(fulfilled: promises)
                }.done {
                    completionHandler(.newData)
                }.catch { _ in
                    completionHandler(.failed)
                }
            case NotificationCategory.DELETE_TEAM_SESSION:
                // This can be sent directly from admin panel to cancel existing pairing process
                guard let pubkey = userInfo["pubkey"] as? String, let session = try TeamSession.all().first(where: { $0.signingPubKey == pubkey }) else {
                    completionHandler(UIBackgroundFetchResult.failed)
                    return
                }
                do {
                    try session.delete(ifNotCreated: true)
                    NotificationCenter.default.postMain(name: .sessionEnded, object: nil, userInfo: [NotificationContentKey.sessionId: session.id])
                    completionHandler(.newData)
                } catch {
                    completionHandler(.failed)
                }
            default: completionHandler(.noData)
            }
        } catch {
            Logger.shared.error("Could not get sessions.", error: error)
            completionHandler(UIBackgroundFetchResult.failed)
        }
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

    /*
     * Parses the push notification then ends session or presents the requestview.
     *
     * Only one calling function actually uses the returned presentation options.
     */
    private func handleNotification(_ notification: UNNotification) -> UNNotificationPresentationOptions {
        switch notification.request.content.categoryIdentifier {
        case NotificationCategory.KEYN_NOTIFICATION:
            return [.alert]
        case NotificationCategory.ONBOARDING_NUDGE:
            DispatchQueue.main.async {
                if let vc = AppDelegate.startupService.window?.rootViewController as? RootViewController {
                    vc.selectedIndex = 1
                }
            }
            return [.alert]
        case NotificationCategory.SYNC,
             NotificationCategory.DELETE_TEAM_SESSION:
            return []
        default:
            break
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
                if let sessionID = keynRequest.sessionID, let session = try BrowserSession.get(id: sessionID, context: nil) {
                    firstly {
                        session.delete(notify: false)
                    }.done {
                        NotificationCenter.default.postMain(name: .sessionEnded, object: nil, userInfo: [NotificationContentKey.sessionId: sessionID])
                    }.catch { error in
                        Logger.shared.error("Could not end session.", error: nil, userInfo: ["error": error as Any])
                    }
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

        // This is disabled for now, because it causes requests to not appear if time of phone and device are not in sync
//        guard Date(timeIntervalSince1970: keynRequest.sentTimestamp / 1000).timeIntervalSinceNow > -180 else {
//            Logger.shared.warning("Got a notification older than 3 minutes. I will be ignoring it.")
//            return []
//        }

        if keynRequest.type == .addBulk {
            do {
                guard let sessionID = keynRequest.sessionID, let session = try BrowserSession.get(id: sessionID, context: nil) else {
                    throw CodingError.missingData
                }
                #warning("TODO: Improve this by using background fetching in notification processor.")
                firstly {
                    self.pollQueue(attempts: 1, session: session, shortPolling: true, context: nil)
                }.done(on: .main) { accounts in
                    var request = keynRequest
                    request.accounts = accounts
                    AuthorizationGuard.launchRequestView(with: request)
                }.catchLog("Error getting password change confirmation from persistent queue.")
                return [.sound]
            } catch {
                Logger.shared.error("Could not get session.", error: error)
                return []
            }
        } else {
            DispatchQueue.main.async {
                AuthorizationGuard.launchRequestView(with: keynRequest)
            }
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

    private func waitForPasswordChangeConfirmation(notification: Notification) {
        guard var session = notification.object as? BrowserSession else {
            Logger.shared.warning("Received notification from unexpected object")
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
        firstly {
            self.pollQueue(attempts: PASSWORD_CHANGE_CONFIRMATION_POLLING_ATTEMPTS, session: session, shortPolling: false, context: notification.userInfo?["context"] as? LAContext)
        }.ensure {
            if session.backgroundTask != UIBackgroundTaskIdentifier.invalid.rawValue {
                let id = UIBackgroundTaskIdentifier(rawValue: session.backgroundTask)
                UIApplication.shared.endBackgroundTask(id)
            }
        }.catchLog("Error getting password change confirmation from persistent queue.")
    }

    private func checkPersistentQueue(notification: Notification) {
        do {
            for session in try BrowserSession.all() {
                let _ = self.pollQueue(attempts: 1, session: session, shortPolling: true, context: nil)
            }
        } catch {
            Logger.shared.error("Could not get sessions.", error: error)
        }
    }

    private func pollQueue(attempts: Int, session: BrowserSession, shortPolling: Bool, context: LAContext?) -> Promise<[BulkAccount]?> {
        return firstly {
            session.getPersistentQueueMessages(shortPolling: shortPolling)
        }.then { (messages: [KeynPersistentQueueMessage]) -> Promise<[BulkAccount]?> in
            if messages.isEmpty {
                return attempts > 1 ? self.pollQueue(attempts: attempts - 1, session: session, shortPolling: shortPolling, context: context) : .value(nil)
            } else {
                var accounts: [BulkAccount]? = nil
                for message in messages {
                    if let bulkAccounts = try self.handlePersistentQueueMessage(keynMessage: message, session: session, context: context) {
                        accounts = bulkAccounts
                    }
                }
                return .value(accounts)
            }
        }
    }

    private func handlePersistentQueueMessage(keynMessage: KeynPersistentQueueMessage, session: BrowserSession, context: LAContext?) throws -> [BulkAccount]? {
        guard let receiptHandle = keynMessage.receiptHandle else  {
            throw CodingError.missingData
        }
        var result: [BulkAccount]?
        switch keynMessage.type {
        case .confirm:
            guard let accountId = keynMessage.accountID else  {
                throw CodingError.missingData
            }
            var account = try UserAccount.get(id: accountId, context: context)
            guard account != nil else {
                throw AccountError.notFound
            }
            guard let result = keynMessage.passwordSuccessfullyChanged else {
                throw CodingError.missingData
            }
            if result {
                try account!.updatePasswordAfterConfirmation(context: context)
            }
        case .preferences:
            guard let accountId = keynMessage.accountID else  {
                throw CodingError.missingData
            }
            var account = try UserAccount.get(id: accountId, context: context)
            guard account != nil else {
                throw AccountError.notFound
            }
            try account!.update(username: nil, password: nil, siteName: nil, url: nil, askToLogin: keynMessage.askToLogin, askToChange: keynMessage.askToChange, enabled: nil)
        case .addBulk:
            result = keynMessage.accounts!
        default:
            Logger.shared.warning("Unknown message type received", userInfo: ["messageType": keynMessage.type.rawValue ])
        }
        session.deleteFromPersistentQueue(receiptHandle: receiptHandle)
        return result
    }

    // DEBUG
    private func reprocess(content: UNNotificationContent) -> UNNotificationContent {
        guard let mutableContent = (content.mutableCopy() as? UNMutableNotificationContent) else {
            return content
        }

        do {
            return try NotificationProcessor.process(content: mutableContent)
        } catch {
            Logger.shared.warning("Error reprocessing data", error: error)
        }

        return content
    }

}
