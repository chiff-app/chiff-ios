/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UserNotifications

enum NotificationExtensionError: KeynError {
    case decodeCiphertext
    case decodeSessionId
}

/*
 * This class does processes push notifications before they appear to the user.
 * It gets called from the KeynNotificationExtension.
 */
class NotificationProcessor {

    static func process(content: UNMutableNotificationContent) throws -> UNMutableNotificationContent {
        guard let ciphertext = content.userInfo[NotificationContentKey.data] as? String else {
            throw NotificationExtensionError.decodeCiphertext
        }

        guard let id = content.userInfo[NotificationContentKey.sessionId] as? String else {
            throw NotificationExtensionError.decodeSessionId
        }

        guard let session = try Session.get(id: id) else {
            throw SessionError.doesntExist
        }

        let keynRequest: KeynRequest = try session.decrypt(message: ciphertext)
        content.userInfo["keynRequest"] = try PropertyListEncoder().encode(keynRequest)

        let siteName = keynRequest.siteName ?? "Unknown"

        switch keynRequest.type {
        case .add, .addAndLogin, .addToExisting:
            content.title = "notifications.add_account".localized
            content.body = String(format: "notifications.in_on".localized, siteName, session.browser, session.os)
        case .addBulk:
            content.title = "notifications.add_accounts".localized
            content.body = String(format: "notifications.accounts_from".localized, keynRequest.count!, session.browser, session.os)
        case .end:
            content.title = "notifications.end_session".localized
            content.body = String(format: "notifications.this_on_that".localized, session.browser, session.os)
        case .change:
            content.title = "notifications.change_password".localized
            content.body = String(format: "notifications.in_on".localized, siteName, session.browser, session.os)
        case .login:
            content.title = "notifications.login".localized
            content.body = String(format: "notifications.in_on".localized, siteName, session.browser, session.os)
        case .fill:
            content.title = "notifications.fill_password".localized
            content.body = String(format: "notifications.in_on".localized, siteName, session.browser, session.os)
        case .pair:
            content.title = "notifications.pairing".localized
            content.body = String(format: "notifications.this_on_that".localized, session.browser, session.os)
        default:
            content.body = "Unknown request"
        }

        // temp
        content.userInfo[NotificationContentKey.type] = keynRequest.type.rawValue

        return content
    }

}
