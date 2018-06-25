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
            
            let siteName = browserMessage.n ?? "Unknown"
            var addSiteInfo = false

            switch browserMessage.r {
            case .add:
                content.title = "Add site request"
                content.body = "\(siteName) on \(session.browser) on \(session.os)."
                addSiteInfo = true
            case.end:
                content.title = "Session ended"
                content.body = "\(session.browser) on \(session.os)."
            case .change, .addAndChange:
                content.title = "Change password request"
                content.body = "\(siteName) on \(session.browser) on \(session.os)."
                addSiteInfo = true
            case .login:
                content.title = "Login request"
                content.body = "\(siteName) on \(session.browser) on \(session.os)."
                if let password = browserMessage.p {
                    content.userInfo["password"] = password
                }
                if let username = browserMessage.u {
                    content.userInfo["username"] = username
                }
                addSiteInfo = true
            case .pair:
                content.title = "Pairing request"
                content.body = "\(session.browser) on \(session.os)."
            case .confirm:
                content.title = "Password change confirmation"
                if browserMessage.v! {
                    content.body = "Password for \(siteName) on \(session.browser) on \(session.os) succesfully changed."
                } else {
                    content.body = "Password change for \(siteName) on \(session.browser) on \(session.os) failed."
                }
                addSiteInfo = true
                content.userInfo["changeValue"] = browserMessage.v!
            default:
                content.body = "Unknown request received"
            }
            
            if addSiteInfo {
                content.userInfo["siteName"] = siteName
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
