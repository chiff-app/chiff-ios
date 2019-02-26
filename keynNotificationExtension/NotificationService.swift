/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UserNotifications

class NotificationService: UNNotificationServiceExtension {

    var contentHandler: ((UNNotificationContent) -> Void)?
    var content: UNMutableNotificationContent?

    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler

        guard let content = (request.content.mutableCopy() as? UNMutableNotificationContent) else {
            contentHandler(request.content)
            return
        }

        do {
            let processedContent = try NotificationProcessor.process(content: content)
            contentHandler(processedContent)
        } catch {
            content.userInfo["error"] = error.localizedDescription
            contentHandler(content)
        }
    }
    
    // Called just before the extension will be terminated by the system.
    // Use this as an opportunity to deliver your "best attempt" at modified content,
    // otherwise the original push payload will be used.
    override func serviceExtensionTimeWillExpire() {
        if let contentHandler = contentHandler, let content = (content?.mutableCopy() as? UNMutableNotificationContent) {
            content.userInfo["expried"] = true
            contentHandler(content)
        }
    }

}
