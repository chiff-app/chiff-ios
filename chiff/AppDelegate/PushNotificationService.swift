//
//  PushNotificationService.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

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
     */
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        guard let typeString = userInfo["type"] as? String,
              let type = NotificationType(rawValue: typeString),
              type == .sync else {
            completionHandler(.noData)
            return
        }
        guard let accounts = userInfo[NotificationContentKey.accounts.rawValue] as? Bool,
              let userTeamSessions = userInfo[NotificationContentKey.userTeamSessions.rawValue] as? Bool,
              let sessions = userInfo[NotificationContentKey.sessions.rawValue] as? Bool else {
            completionHandler(.failed)
            return
        }
        var promises: [Promise<Void>] = []
        if sessions {
            promises.append(firstly {
                // First sync team session, because keys may have changed.
                sessions ? TeamSession.sync(context: nil) : .value(())
            }.map {
                TeamSession.updateAllTeamSessions()
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
            completionHandler(UIBackgroundFetchResult.newData)
        }.catch { _ in
            completionHandler(UIBackgroundFetchResult.failed)
        }
    }

    // Called whenever the app is in the foreground and notification comes in.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
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
     * Only one calling function actually uses the returned presentation options.
     */
    private func handleNotification(_ notification: UNNotification) -> UNNotificationPresentationOptions {
        switch notification.request.content.categoryIdentifier {
        case NotificationCategory.onboardingNudge:
            DispatchQueue.main.async {
                if let rootController = AppDelegate.shared.startupService.window?.rootViewController as? RootViewController {
                    rootController.selectedIndex = 1
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
        guard let encodedChiffRequest: Data = content.userInfo["chiffRequest"] as? Data else {
            Logger.shared.error("Cannot find a ChiffRequest in the push notification.")
            return []
        }

        guard let chiffRequest = try? PropertyListDecoder().decode(ChiffRequest.self, from: encodedChiffRequest) else {
            Logger.shared.error("Cannot decode the ChiffRequest sent through a push notification.")
            return []
        }
        if chiffRequest.type == .end {
            do {
                if let sessionID = chiffRequest.sessionID, let session = try BrowserSession.get(id: sessionID, context: nil) {
                    firstly {
                        session.delete(notify: false)
                    }.done {
                        NotificationCenter.default.postMain(name: .sessionEnded, object: nil, userInfo: [NotificationContentKey.sessionID.rawValue: sessionID])
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
            AuthorizationGuard.shared.launchRequestView(with: chiffRequest)
        }

        // This is disabled for now, because it causes requests to not appear if time of phone and device are not in sync
//        guard Date(timeIntervalSince1970: ChiffRequest.sentTimestamp / 1000).timeIntervalSinceNow > -180 else {
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
