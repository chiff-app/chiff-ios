/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UserNotifications
import PromiseKit
import LocalAuthentication

enum NotificationExtensionError: Error {
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

        guard let session = try BrowserSession.get(id: id, context: nil) else {
            throw SessionError.doesntExist
        }

        let keynRequest: KeynRequest = try session.decrypt(message: ciphertext)
        let siteName = keynRequest.siteName ?? "Unknown"

        switch keynRequest.type {
        case .add, .addAndLogin, .webauthnCreate:
            content.title = "notifications.add_account".localized
            content.body = String(format: "notifications.this_on_that".localized, siteName, session.title)
        case .addBulk:
            content.title = "notifications.add_accounts".localized
            content.body = String(format: "notifications.accounts_from".localized, keynRequest.count!, session.title)
        case .end:
            content.title = "notifications.end_session".localized
            content.body = session.title
        case .change:
            content.title = "notifications.change_password".localized
            content.body = String(format: "notifications.this_on_that".localized, siteName, session.title)
        case .login, .addToExisting, .webauthnLogin:
            content.title = "notifications.login".localized
            content.body = String(format: "notifications.this_on_that".localized, siteName, session.title)
        case .fill, .getDetails:
            content.title = "notifications.get_password".localized
            content.body = String(format: "notifications.this_on_that".localized, siteName, session.title)
        case .pair:
            content.title = "notifications.pairing".localized
            content.body = session.title
        case .adminLogin:
            content.title = "notifications.team_admin_login".localized
            content.body = session.title
        case .bulkLogin:
            content.title = "notifications.login".localized
            content.body = String(format: "notifications.accounts_from".localized, keynRequest.accountIDs!.count, session.title)
        default:
            content.body = "Unknown request"
        }

        content.userInfo[NotificationContentKey.type] = keynRequest.type.rawValue
        content.userInfo["keynRequest"] = try PropertyListEncoder().encode(keynRequest)
        return content
    }

}
