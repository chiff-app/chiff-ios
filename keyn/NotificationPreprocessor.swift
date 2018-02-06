import UserNotifications

class NotificationPreprocessor {

    // Decrypt message, get session info so we can show pretty push message.
    static func enrich(notification content: UNMutableNotificationContent?) -> UNMutableNotificationContent? {
        guard let content = content else {
            return nil
        }

        if let ciphertext = content.userInfo["data"] as? String, let id = content.userInfo["sessionID"] as? String {
            do {
                if let session = try Session.getSession(id: id) {
                    let message = try session.decrypt(message: ciphertext)
                    let parts = message.split(separator: " ")
                    let siteID = parts[0]
                    let browserTab = parts[1]

                    let site = Site.get(id: String(siteID))
                    content.body = "Login request for \(site.name) from \(session.browser) on \(session.os)."
                    content.userInfo["siteID"] = siteID
                    content.userInfo["browserTab"] = browserTab

                    return content
                }
            } catch {
                print("Session could not be decoded: \(error)")
            }
        }

        return nil
    }

}
