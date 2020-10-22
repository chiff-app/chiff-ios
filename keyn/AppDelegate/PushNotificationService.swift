/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import Foundation
import UIKit
import UserNotifications
import LocalAuthentication
import PromiseKit
import os.log

/*
 * Handles push notification that come from outside the app.
 */
class PushNotificationService: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        handlePendingNotifications()

        return true
    }

    /*
     * Tells the app that a remote notification arrived that indicates there is data to be fetched.
     * Called when we set "content-available": 1
     * After this the userNotificationCenter function will also be called.
     */
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        do {
            guard let typeString = userInfo["type"] as? String, let type = BackgroundNotificationType(rawValue: typeString) else {
                completionHandler(.failed)
                return
            }
            switch type {
            case .sync:
                guard let accounts = userInfo["accounts"] as? Bool, let userTeamSessions = userInfo["userTeamSessions"] as? Bool, let sessions = userInfo["sessions"] as? Bool else {
                    completionHandler(.failed)
                    return
                }
                var promises: [Promise<Void>] = []
                if sessions {
                    promises.append(firstly {
                        // First sync team session, because keys may have changed.
                        sessions ? TeamSession.sync(context: nil) : .value(())
                    }.map {
                        TeamSession.updateAllTeamSessions(pushed: true)
                    }.asVoid())
                } else if userTeamSessions {
                    promises.append(TeamSession.sync(context: nil))
                }
                if accounts {
                    promises.append(UserAccount.sync(context: nil))
                }
                firstly {
                    when(fulfilled: promises)
                }.done {
                    completionHandler(.newData)
                }.catch { error in
                    Logger.shared.warning("Failed to sync after push message", error: error)
                    completionHandler(.failed)
                }
            case .deleteTeamSession:
                // This can be sent directly from admin panel to cancel existing pairing process

                guard let id = userInfo["id"] as? String, let session = try TeamSession.get(id: id, context: nil) else {
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
        _ = handleNotification(response.notification)
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
        case NotificationCategory.onboardingNudge:
            DispatchQueue.main.async {
                if let vc = AppDelegate.startupService.window?.rootViewController as? RootViewController {
                    vc.selectedIndex = 1
                }
            }
            return [.alert]
        default:
            break
        }

        var content: UNNotificationContent = notification.request.content
        if !content.isProcessed {
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

        DispatchQueue.main.async {
            AuthorizationGuard.shared.launchRequestView(with: keynRequest)
        }

        // This is disabled for now, because it causes requests to not appear if time of phone and device are not in sync
//        guard Date(timeIntervalSince1970: keynRequest.sentTimestamp / 1000).timeIntervalSinceNow > -180 else {
//            Logger.shared.warning("Got a notification older than 3 minutes. I will be ignoring it.")
//            return []
//        }

        return [.sound]
    }

    private func handlePendingNotifications() {
        UNUserNotificationCenter.current().getDeliveredNotifications { (notifications) in
            for notification in notifications {
                _ = self.handleNotification(notification)
            }
        }
    }

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
