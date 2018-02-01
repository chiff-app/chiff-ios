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
            if let ciphertext = bestAttemptContent.userInfo["data"] as? String,
                let id = bestAttemptContent.userInfo["id"] as? String {
                do {
                    if let session = try Session.getSession(id: id) {
                        let siteID = try session.decrypt(message: ciphertext)
                        if let account = try Account.get(siteID: siteID) {
                            //bestAttemptContent.title = "Login request for \(account.site.name)"
                            bestAttemptContent.body = "Login request for \(account.site.name) from \(session.browser) on \(session.os)."
                        }
                        bestAttemptContent.userInfo["data"] = siteID
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
