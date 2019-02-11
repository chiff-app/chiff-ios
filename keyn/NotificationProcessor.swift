/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UserNotifications

enum NotificationExtensionError: Error {
    case StringCast(String)
    case Decryption
    case Session
}

class NotificationProcessor {
    class func process(content: UNMutableNotificationContent) throws -> UNMutableNotificationContent {
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
            if let password = browserMessage.p {
                content.userInfo["password"] = password
            }
            if let username = browserMessage.u {
                content.userInfo["username"] = username
            }
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
        case .fill:
            content.title = "Fill password request"
            content.body = "\(siteName) on \(session.browser) on \(session.os)."
            addSiteInfo = true
        case .pair:
            content.title = "Pairing request"
            content.body = "\(session.browser) on \(session.os)."
        default:
            content.body = "Unknown request received"
        }
        
        if addSiteInfo {
            content.userInfo["siteName"] = siteName
            content.userInfo["siteID"] = browserMessage.s
            content.userInfo["browserTab"] = browserMessage.b
            content.userInfo["requestType"] = browserMessage.r.rawValue
        }

        return content
    }
}
