//
//  NotificationManagerExtension.swift
//  keyn
//
//  Created by Bas Doorn on 23/10/2019.
//  Copyright © 2019 keyn. All rights reserved.
//

import UIKit
import UserNotifications

// This is in an extension, so the target membership of the NotifcationManager can be set to just keyn, not the extensions
struct PushNotifications {

    static func register(completionHandler: @escaping (_ result: Bool) -> Void) {
        requestAuthorization { (result) in
            if result {
                UIApplication.shared.registerForRemoteNotifications()
                completionHandler(true)
            } else {
                completionHandler(false)
            }
        }
    }

    static func requestAuthorization(completionHandler: @escaping (_ result: Bool) -> Void) {
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
        let keyn = UNNotificationCategory(identifier: NotificationCategory.KEYN_NOTIFICATION,
                                          actions: [],
                                          intentIdentifiers: [],
                                          options: .customDismissAction)
        let nudge = UNNotificationCategory(identifier: NotificationCategory.ONBOARDING_NUDGE,
                                           actions: [],
                                           intentIdentifiers: [],
                                           options: .customDismissAction)
        let center = UNUserNotificationCenter.current()
        center.delegate = AppDelegate.notificationService
        center.setNotificationCategories([passwordRequest, endSession, passwordChangeConfirmation, keyn, nudge])
        center.requestAuthorization(options: [.alert, .sound]) { (granted, error) in
            DispatchQueue.main.async {
                Properties.deniedPushNotifications = !granted
                if granted {
                    completionHandler(true)
                } else {
                    completionHandler(false)
                }
            }
        }
    }

}
