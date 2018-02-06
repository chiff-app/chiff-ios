//
//  NotificationService.swift
//  keynNotificationExtension
//
//  Created by bas on 19/01/2018.
//  Copyright © 2018 keyn. All rights reserved.
//

import UserNotifications

class NotificationService: UNNotificationServiceExtension {

    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
        if let bestAttemptContent = bestAttemptContent {
            if let ciphertext = bestAttemptContent.userInfo["data"] as? String, let id = bestAttemptContent.userInfo["sessionID"] as? String {
                do {
                    if let session = try Session.getSession(id: id) {
                        let message = try session.decrypt(message: ciphertext)
                        let parts = message.split(separator: " ")
                        let siteID = parts[0]
                        let browserTab = parts[1]

                        let site = Site.get(id: String(siteID))
                        bestAttemptContent.body = "Login request for \(site.name) from \(session.browser) on \(session.os)."
                        bestAttemptContent.userInfo["siteID"] = siteID
                        bestAttemptContent.userInfo["browserTab"] = browserTab
                    }
                } catch {
                    print("Session could not be decoded: \(error)")
                }
            }
            contentHandler(bestAttemptContent)
        }
    }

    override func serviceExtensionTimeWillExpire() {
        // Called just before the extension will be terminated by the system.
        // Use this as an opportunity to deliver your "best attempt" at modified content, otherwise the original push payload will be used.
        if let contentHandler = contentHandler, let bestAttemptContent =  bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }

}
