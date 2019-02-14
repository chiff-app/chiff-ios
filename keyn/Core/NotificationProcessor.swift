/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UserNotifications

enum NotificationExtensionError: Error {
    case decodeCiphertext
    case decodeSessionId
}

class NotificationProcessor {
    
    class func process(content: UNMutableNotificationContent) throws -> UNMutableNotificationContent {
        guard let ciphertext = content.userInfo[NotificationContentKey.data] as? String else {
            throw NotificationExtensionError.decodeCiphertext
        }
        
        guard let id = content.userInfo[NotificationContentKey.sessionId] as? String else {
            throw NotificationExtensionError.decodeSessionId
        }
        
        guard let session = try Session.getSession(id: id) else {
            throw SessionError.exists
        }
        
        let browserMessage: BrowserMessage = try session.decrypt(message: ciphertext)
        
        content.userInfo[NotificationContentKey.requestType] = browserMessage.r.rawValue
        
        let siteName = browserMessage.n ?? "Unknown"
        var addSiteInfo = false
        
        switch browserMessage.r {
        case .add:
            content.title = "Add site request"
            content.body = "\(siteName) on \(session.browser) on \(session.os)."
            if let password = browserMessage.p {
                content.userInfo[NotificationContentKey.password] = password
            }
            if let username = browserMessage.u {
                content.userInfo[NotificationContentKey.username] = username
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
            content.userInfo[NotificationContentKey.siteName] = siteName
            content.userInfo[NotificationContentKey.siteId] = browserMessage.s
            content.userInfo[NotificationContentKey.browserTab] = browserMessage.b
            content.userInfo[NotificationContentKey.requestType] = browserMessage.r.rawValue
        }

        return content
    }
    
}
