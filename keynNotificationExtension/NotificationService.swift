import UserNotifications
import JustLog

class NotificationService: UNNotificationServiceExtension {

    var contentHandler: ((UNNotificationContent) -> Void)?
    var content: UNMutableNotificationContent?
    let processor = NotificationProcessor()

    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        
        guard let content = (request.content.mutableCopy() as? UNMutableNotificationContent) else {
            return
        }
        do {
            let processContent = try processor.process(content: content)
            contentHandler(processContent)
        } catch {
            print(error)
        }
        contentHandler(content)
    }
    

    // Called just before the extension will be terminated by the system.
    // Use this as an opportunity to deliver your "best attempt" at modified content,
    // otherwise the original push payload will be used.
    override func serviceExtensionTimeWillExpire() {
        if let contentHandler = contentHandler, let content = content {
            contentHandler(content)
        }
    }

}
