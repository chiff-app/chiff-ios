/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UserNotifications

enum NotificationExtensionError: KeynError {
    case decodeCiphertext
    case decodeSessionId
}

class NotificationProcessor {

    static func process(content: UNMutableNotificationContent) throws -> UNMutableNotificationContent {
        guard let ciphertext = content.userInfo[NotificationContentKey.data] as? String else {
            throw NotificationExtensionError.decodeCiphertext
        }

        guard let id = content.userInfo[NotificationContentKey.sessionId] as? String else {
            throw NotificationExtensionError.decodeSessionId
        }

        guard let session = try Session.get(id: id) else {
            throw SessionError.exists
        }

        let keynRequest = try session.decrypt(message: ciphertext)
        content.userInfo["keynRequest"] = try PropertyListEncoder().encode(keynRequest)

        let siteName = keynRequest.siteName ?? "Unknown"

        switch keynRequest.type {
        case .add:
            content.title = "Add site request"
            content.body = "\(siteName) on \(session.browser) on \(session.os)."
        case .end:
            content.title = "Session ended"
            content.body = "\(session.browser) on \(session.os)."
        case .change:
            content.title = "Change password request"
            content.body = "\(siteName) on \(session.browser) on \(session.os)."
        case .login:
            content.title = "Login request"
            content.body = "\(siteName) on \(session.browser) on \(session.os)."
        case .fill:
            content.title = "Fill password request"
            content.body = "\(siteName) on \(session.browser) on \(session.os)."
        case .pair:
            content.title = "Pairing request"
            content.body = "\(session.browser) on \(session.os)."
        default:
            content.body = "Unknown request"
        }

        // temp
        content.userInfo[NotificationContentKey.type] = keynRequest.type.rawValue

        return content
    }

}