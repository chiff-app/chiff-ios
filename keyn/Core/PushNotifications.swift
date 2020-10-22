//
//  NotificationManagerExtension.swift
//  keyn
//
//  Created by Bas Doorn on 23/10/2019.
//  Copyright © 2019 keyn. All rights reserved.
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
        let passwordRequest = UNNotificationCategory(identifier: NotificationCategory.PASSWORD_REQUEST,
                                                     actions: [],
                                                     intentIdentifiers: [],
                                                     options: .customDismissAction)
        let endSession = UNNotificationCategory(identifier: NotificationCategory.END_SESSION,
                                                actions: [],
                                                intentIdentifiers: [],
                                                options: UNNotificationCategoryOptions(rawValue: 0))
        let passwordChangeConfirmation = UNNotificationCategory(identifier: NotificationCategory.CHANGE_CONFIRMATION,
                                                                actions: [],
                                                                intentIdentifiers: [],
                                                                options: UNNotificationCategoryOptions(rawValue: 0))
        let nudge = UNNotificationCategory(identifier: NotificationCategory.ONBOARDING_NUDGE,
                                           actions: [],
                                           intentIdentifiers: [],
                                           options: .customDismissAction)
        let center = UNUserNotificationCenter.current()
        center.delegate = AppDelegate.notificationService
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
