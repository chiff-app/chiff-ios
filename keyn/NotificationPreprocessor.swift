import UserNotifications
import os.log

class NotificationPreprocessor {

    // Decrypt message, get session info so we can show pretty push message.
    static func enrich(notification content: UNMutableNotificationContent?) -> UNMutableNotificationContent? {
        guard let content = content else {
            return nil
        }

        if let ciphertext = content.userInfo["data"] as? String, let id = content.userInfo["sessionID"] as? String {
            do {
                if let session = try Session.getSession(id: id) {
                    let browserMessage: BrowserMessage = try session.decrypt(message: ciphertext)

                    content.userInfo["requestType"] = browserMessage.r.rawValue
                    if browserMessage.r == .end {
                        content.body = "Session ended by \(session.browser) on \(session.os)."
                    } else {
                        if let siteName = browserMessage.n {
                            content.body = "Login request for \(siteName) from \(session.browser) on \(session.os)."
                            content.userInfo["siteName"] = siteName
                        } else {
                            content.body = "Login request from \(session.browser) on \(session.os)."
                            content.userInfo["siteName"] = "Unknown"
                        }
                        
                        content.userInfo["siteID"] = browserMessage.s
                        content.userInfo["browserTab"] = browserMessage.b
                        content.userInfo["requestType"] = browserMessage.r.rawValue
                    }

                    return content
                }
            } catch {
                content.body = "Error: \(error)"
            }
        }

        return content
    }

}
