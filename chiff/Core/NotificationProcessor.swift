//
//  NotificationProcessor.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import UserNotifications
import PromiseKit
import LocalAuthentication

enum NotificationExtensionError: Error {
    case decodeCiphertext
    case decodeSessionId
}

/// This class does processes push notifications before they appear to the user.
/// It gets called from the KeynNotificationExtension.
class NotificationProcessor {

    /// Decrypts the request and sets the correct localized text for the notificaation.
    /// - Parameter content: The content of the push message.
    /// - Throws: May throw an error if decoding or decryption fails.
    /// - Returns: Returns the updated content.
    static func process(content: UNMutableNotificationContent) throws -> UNMutableNotificationContent {
        guard let ciphertext = content.userInfo[NotificationContentKey.data.rawValue] as? String else {
            throw NotificationExtensionError.decodeCiphertext
        }

        guard let id = content.userInfo[NotificationContentKey.sessionID.rawValue] as? String else {
            throw NotificationExtensionError.decodeSessionId
        }

        guard let session = try BrowserSession.get(id: id, context: nil) else {
            throw SessionError.doesntExist
        }

        let request: ChiffRequest = try session.decrypt(message: ciphertext)
        let siteName = request.siteName ?? "Unknown"
        content.title = session.title
        switch request.type {
        case .add, .addAndLogin, .webauthnCreate:
            content.body = String(format: "notifications.add_account".localized, siteName)
        case .addBulk:
            content.body = String(format: "notifications.add_accounts".localized, request.count!)
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
            content.body = String(format: "notifications.create_organisation".localized, request.organisationName!)
        case .bulkLogin:
            content.body = String(format: "notifications.bulk_login".localized, request.accountIDs!.count, session.title)
        default:
            content.body = "Unknown request"
        }

        content.userInfo[NotificationContentKey.type.rawValue] = NotificationType.browser.rawValue
        content.userInfo["chiffRequest"] = try PropertyListEncoder().encode(request)
        return content
    }

}
