//
//  Logger.swift
//  keyn
//
//  Created by Bas Doorn on 11/02/2019.
//  Copyright © 2019 keyn. All rights reserved.
//

import Foundation
import Crashlytics
import Amplitude_iOS
import Firebase

struct Logger {
    
    static let shared = Logger()
    private let crashlytics = Crashlytics.sharedInstance()
    private let amplitude = Amplitude.instance()!

    private init() {
        FirebaseConfiguration.shared.setLoggerLevel(.min)
        Analytics.setAnalyticsCollectionEnabled(false)
        FirebaseApp.configure()
        amplitude.initializeApiKey(Properties.amplitudeToken)
        amplitude.disableIdfaTracking()
        amplitude.disableLocationListening()
        amplitude.set(userProperties: [
            .accountCount: Properties.accountCount,
            .pairingCount: Properties.sessionCount,
            .subscribed: Properties.hasValidSubscription,
            .infoNotifications: Properties.infoNotifications,
            .backupCompleted: Seed.paperBackupCompleted
        ])
        if let userId = Properties.userId {
            setUserId(userId: userId)
        }
    }

    func setAnalyticsLogging(value: Bool) {
        amplitude.optOut = !value
    }

    func setUserId(userId: String?) {
        crashlytics.setUserIdentifier(userId)
        amplitude.setUserId(userId)
    }

    func uploadAnalytics() {
        amplitude.uploadEvents()
    }

    func warning(_ message: String, error: Error? = nil, userInfo: [String: Any]? = nil, _ file: StaticString = #file, _ function: StaticString = #function, _ line: UInt = #line) {
        #if DEBUG
        print("--------- ⚠️ WARNING: \(String(describing: error)). \(message) ---------")
        #endif
        guard Properties.errorLogging else {
            return
        }
        crashlytics.setObjectValue(message, forKey: "message")
        crashlytics.setObjectValue("warning", forKey: "level")
        crashlytics.setObjectValue(file, forKey: "file")
        crashlytics.setObjectValue(function, forKey: "function")
        crashlytics.setIntValue(Int32(line), forKey: "line")
        if let error = error {
            crashlytics.recordError(getNSError(error), withAdditionalUserInfo: userInfo)
        } else {
            let error = NSError(domain: "NoError", code: 42, userInfo: nil)
            crashlytics.recordError(error, withAdditionalUserInfo: userInfo)
        }
    }
    
    func error(_ message: String, error: Error? = nil, userInfo: [String: Any]? = nil, override: Bool = false, _ file: StaticString = #file, _ function: StaticString = #function, _ line: UInt = #line) {
        #if DEBUG
        print("--------- ☠️ ERROR: \(String(describing: error)). \(message) --------- ")
        #endif
        guard Properties.errorLogging || override else {
            return
        }
        crashlytics.setObjectValue(message, forKey: "message")
        crashlytics.setObjectValue("error", forKey: "level")
        crashlytics.setObjectValue(file, forKey: "file")
        crashlytics.setObjectValue(function, forKey: "function")
        crashlytics.setIntValue(Int32(line), forKey: "line")
        if let error = error {
            crashlytics.recordError(getNSError(error), withAdditionalUserInfo: userInfo)
        } else {
            let error = NSError(domain: "NoError", code: 42, userInfo: nil)
            crashlytics.recordError(error, withAdditionalUserInfo: userInfo)
        }
    }

    func analytics(_ event: AnalyticsEvent, properties: [AnalyticsEventProperty: Any]? = nil, override: Bool = false) {
        print("ℹ️ EVENT: \(event)")
        guard Properties.analyticsLogging || override else {
            return
        }
        amplitude.logEvent(event: event, properties: properties)
    }
    
    private func getNSError(_ error: Error) -> NSError {
        if let error = error as? KeynError {
            return error.nsError
        } else  {
            return error as NSError
        }
    }

}

protocol KeynError: Error {
    var nsError: NSError { get }
}

// TODO: Differentiate this for Crashlytics. See https://firebase.google.com/docs/crashlytics/customize-crash-reports
extension KeynError {
    var nsError: NSError {
        return NSError(
            domain: "\(type(of: self)).\(self)",
            code: 42,
            userInfo: nil)
    }
}
