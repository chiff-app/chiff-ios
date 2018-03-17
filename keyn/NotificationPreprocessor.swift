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
                    let browserMessage: BrowserMessage = try session.decrypt(message: ciphertext)

                    content.userInfo["requestType"] = browserMessage.r.rawValue
                    if browserMessage.r == .end {
                        content.body = "Session ended by \(session.browser) on \(session.os)."
                    } else {
                        let siteID = browserMessage.s

                        guard let site = Site.get(id: siteID!) else {
                            return content
                        }

                        content.body = "Login request for \(site.name) from \(session.browser) on \(session.os)."
                        content.userInfo["siteID"] = siteID
                        content.userInfo["browserTab"] = browserMessage.b
                        content.userInfo["requestType"] = browserMessage.r.rawValue
                    }

                    return content
                }
            } catch {
                print("Session could not be decoded: \(error)")
            }
        }

        return content
    }

}
