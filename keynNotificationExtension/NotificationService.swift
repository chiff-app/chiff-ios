import UserNotifications

class NotificationService: UNNotificationServiceExtension {

    var contentHandler: ((UNNotificationContent) -> Void)?
    var content: UNMutableNotificationContent?

    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        content = (request.content.mutableCopy() as? UNMutableNotificationContent)

        if let content = NotificationServiceHelper.decrypt(content) {
            contentHandler(content)
        }
    }

    // Called just before the extension will be terminated by the system.
    // Use this as an opportunity to deliver your "best attempt" at modified content,
    // otherwise the original push payload will be used.
    override func serviceExtensionTimeWillExpire() {
        if let contentHandler = contentHandler, let content =  content {
            contentHandler(content)
        }
    }

}
