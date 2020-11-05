//
//  NotificationManagerExtension.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import UIKit
import UserNotifications
import PromiseKit

struct PushNotifications {

    static func register() -> Guarantee<Bool> {
        return firstly {
            requestAuthorization()
        }.map { result in
            if result {
                UIApplication.shared.registerForRemoteNotifications()
            }
            return result
        }.recover { _ in
            return .value(false)
        }
    }

    static func requestAuthorization() -> Guarantee<Bool> {
        let passwordRequest = UNNotificationCategory(identifier: NotificationCategory.passwordRequest,
                                                     actions: [],
                                                     intentIdentifiers: [],
                                                     options: .customDismissAction)
        let endSession = UNNotificationCategory(identifier: NotificationCategory.endSession,
                                                actions: [],
                                                intentIdentifiers: [],
                                                options: UNNotificationCategoryOptions(rawValue: 0))
        let passwordChangeConfirmation = UNNotificationCategory(identifier: NotificationCategory.changeConfirmation,
                                                                actions: [],
                                                                intentIdentifiers: [],
                                                                options: UNNotificationCategoryOptions(rawValue: 0))
        let nudge = UNNotificationCategory(identifier: NotificationCategory.onboardingNudge,
                                           actions: [],
                                           intentIdentifiers: [],
                                           options: .customDismissAction)
        let center = UNUserNotificationCenter.current()
        center.delegate = AppDelegate.shared.notificationService
        center.setNotificationCategories([passwordRequest, endSession, passwordChangeConfirmation, nudge])
        return Promise { seal in
            center.requestAuthorization(options: [.alert, .sound]) { (granted, _) in
                Properties.deniedPushNotifications = !granted
                seal.fulfill(granted)
            }
        }.recover { _ in
            return .value(false)
        }
    }

}
