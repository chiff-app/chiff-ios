import UserNotifications
import os.log

enum NotificationExtensionError: Error {
    case StringCast(String)
    case Decryption
    case Session
}

class NotificationService: UNNotificationServiceExtension {

    var contentHandler: ((UNNotificationContent) -> Void)?
    var content: UNMutableNotificationContent?

    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        
        guard let content = (request.content.mutableCopy() as? UNMutableNotificationContent) else {
            return
        }
        
        do {
            guard let ciphertext = content.userInfo["data"] as? String else {
                throw NotificationExtensionError.StringCast("ciphertext")
            }
            
            guard let id = content.userInfo["sessionID"] as? String else {
                throw NotificationExtensionError.StringCast("sessionID")
            }
            
            guard let session = try Session.getSession(id: id) else {
                throw NotificationExtensionError.Session
            }
            
            let browserMessage: BrowserMessage = try session.decrypt(message: ciphertext)
            
            content.userInfo["requestType"] = browserMessage.r.rawValue
            if browserMessage.r == .end {
                content.body = "Session ended by \(session.browser) on \(session.os)."
            } else {
                let type = (browserMessage.r == .add) ? "Add site request" : "Login request"
                if let siteName = browserMessage.n {
                    content.body = "\(type) for \(siteName) from \(session.browser) on \(session.os)."
                    content.userInfo["siteName"] = siteName
                } else {
                    content.body = "\(type) from \(session.browser) on \(session.os)."
                    content.userInfo["siteName"] = "Unknown"
                }
                
                content.userInfo["siteID"] = browserMessage.s
                content.userInfo["browserTab"] = browserMessage.b
                content.userInfo["requestType"] = browserMessage.r.rawValue
            }
        } catch {
            os_log("NotificationError: %@", error.localizedDescription)
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
