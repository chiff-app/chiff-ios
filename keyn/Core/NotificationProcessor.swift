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
        content.title = session.title
        switch keynRequest.type {
        case .add, .addAndLogin, .webauthnCreate:
            content.body = String(format: "notifications.add_account".localized, siteName)
        case .addBulk:
            content.body = String(format: "notifications.add_accounts".localized, keynRequest.count!)
        case .end:
            content.body = "notifications.end_session".localized
        case .change:
            content.body = String(format: "notifications.change_password".localized, siteName)
        case .updateAccount:
            content.body = String(format: "notifications.update_account".localized, siteName)
        case .login, .addToExisting, .webauthnLogin:
            content.body = String(format: "notifications.login".localized, siteName)
        case .fill, .getDetails:
            content.body = String(format: "notifications.get_password".localized, siteName)
        case .adminLogin:
            content.body = String(format: "notifications.team_admin_login".localized, (try? TeamSession.all().first?.title) ?? "notifications.team".localized)
        case .createOrganisation:
            content.body = String(format: "notifications.create_organisation".localized, keynRequest.organisationName!)
        case .bulkLogin:
            content.body = String(format: "notifications.bulk_login".localized, keynRequest.accountIDs!.count, session.title)
        default:
            content.body = "Unknown request"
        }

        content.userInfo[NotificationContentKey.type] = keynRequest.type.rawValue
        content.userInfo["keynRequest"] = try PropertyListEncoder().encode(keynRequest)
        return content
    }

}
