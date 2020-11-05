//
//  Extensions.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import UIKit
import UserNotifications
import OneTimePassword
import Amplitude
import PromiseKit

extension Amplitude {
    func set(userProperties: [AnalyticsUserProperty: Any]) {
        let properties = Dictionary(uniqueKeysWithValues: userProperties.map({ ($0.key.rawValue, $0.value) }))
        self.setUserProperties(properties)
    }

    func logEvent(event: AnalyticsEvent, properties: [AnalyticsEventProperty: Any]? = nil) {
        if let properties = properties {
            self.logEvent(event.rawValue, withEventProperties: Dictionary(uniqueKeysWithValues: properties.map({ ($0.key.rawValue, $0.value) })))
        } else {
            self.logEvent(event.rawValue)
        }
    }
}

extension OSStatus {
    /// A human readable message for the status.
    var message: String {
        if #available(iOS 13.0, *) {
            return (SecCopyErrorMessageString(self, nil) as String?) ?? String(self)
        } else {
            return String(self)
        }
    }
}

extension NotificationCenter {
    func postMain(_ notification: Notification) {
        DispatchQueue.main.async {
            self.post(notification)
        }
    }

    func postMain(name aName: NSNotification.Name, object anObject: Any?) {
        DispatchQueue.main.async {
            self.post(name: aName, object: anObject)
        }
    }

    func postMain(name aName: NSNotification.Name, object anObject: Any?, userInfo aUserInfo: [AnyHashable: Any]? = nil) {
        DispatchQueue.main.async {
            self.post(name: aName, object: anObject, userInfo: aUserInfo)
        }
    }
}

extension CatchMixin {
    func log(_ message: String) -> Promise<T> {
        recover { (error) -> Promise<T> in
            Logger.shared.error(message, error: error)
            throw error
        }
    }

    func catchLog(_ message: String) {
        `catch` { (error) in
            Logger.shared.error(message, error: error)
        }
    }
}

extension Notification.Name {
    static let passwordChangeConfirmation = Notification.Name("PasswordChangeConfirmation")
    static let sessionStarted = Notification.Name("SessionStarted")
    static let sessionUpdated = Notification.Name("SessionUpdated")
    static let sessionEnded = Notification.Name("SessionEnded")
    static let accountsLoaded = Notification.Name("AccountsLoaded")
    static let sharedAccountsChanged = Notification.Name("SharedAccountsChanged")
    static let accountUpdated = Notification.Name("AccountUpdated")
    static let notificationSettingsUpdated = Notification.Name("NotificationSettingsUpdated")
    static let backupCompleted = Notification.Name("BackupCompleted")
    static let newsMessage = Notification.Name("NewsMessage")
}

extension Token {
    var currentPasswordSpaced: String? {
        return self.currentPassword?.components(withLength: 3).joined(separator: " ")
    }
}

extension CharacterSet {
    static var base32WithSpaces: CharacterSet {
        return CharacterSet.letters.union(CharacterSet(["0", "1", "2", "3", "4", "5", "6", "7", " "]))
    }

    static var base32: CharacterSet {
        return CharacterSet.lowercaseLetters.union(CharacterSet(["0", "1", "2", "3", "4", "5", "6", "7"]))
    }
}
