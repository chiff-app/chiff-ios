//
//  Logger.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import Foundation
import FirebaseCrashlytics
import Amplitude
import FirebaseCore
import ChiffCore

struct ChiffLogger: LoggerProtocol {

    private let crashlytics = Crashlytics.crashlytics()
    private let amplitude = Amplitude.instance()

    init() {
        FirebaseConfiguration.shared.setLoggerLevel(.min)
        FirebaseApp.configure()
        amplitude.initializeApiKey(Properties.amplitudeToken)
        amplitude.set(userProperties: [
            .accountCount: Properties.accountCount,
            .pairingCount: BrowserSession.count,
            .backupCompleted: Seed.paperBackupCompleted
        ])
        if let userId = Properties.userId {
            setUserId(userId: userId)
        }
        crashlytics.setCustomValue(Properties.environment.rawValue, forKey: "environment")
    }

    /// Enable / disable analytics logging.
    /// - Parameter value: True to enable, false to disable.
    func setAnalyticsLogging(value: Bool) {
        if !value {
            // Uploading setting change before opting out.
            analytics(.analytics, properties: [.value: value], override: true)
            uploadAnalytics()
        }
        amplitude.optOut = !value
        if value {
            // Upload setting after opting in.
            analytics(.analytics, properties: [.value: value])
        }
    }

    /// Enable / disable error logging.
    /// - Parameter value: True to enable, false to disable.
    func setErrorLogging(value: Bool) {
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(value)
    }

    /// Set the user id for analytics and error logging.
    /// - Parameter userId: The user id.
    func setUserId(userId: String?) {
        if let userId = userId {
            crashlytics.setUserID(userId)
            amplitude.setUserId(userId, startNewSession: false)
        }
    }

    /// Immediately upload analytics events.
    func uploadAnalytics() {
        amplitude.uploadEvents()
    }

    /// Log an error with the warning level.
    /// - Parameters:
    ///   - message: The message
    ///   - error: Optionally, an error object.
    ///   - userInfo: Optionally, additional information
    func warning(_ message: String, error: Error? = nil, userInfo: [String: Any]? = nil, _ file: StaticString = #file, _ function: StaticString = #function, _ line: UInt = #line) {
        #if DEBUG
        print("--------- ⚠️ WARNING: \(String(describing: error)). \(message) ---------")
        #endif
        guard Properties.errorLogging else {
            return
        }
        crashlytics.setCustomValue(message, forKey: "message")
        crashlytics.setCustomValue("warning", forKey: "level")
        crashlytics.setCustomValue(file, forKey: "file")
        crashlytics.setCustomValue(function, forKey: "function")
        crashlytics.setCustomValue(Int32(line), forKey: "line")
        crashlytics.record(error: error ?? KeynError())
    }

    /// Log an error with the error level.
    /// - Parameters:
    ///   - message: The message
    ///   - error: Optionally, an error object.
    ///   - userInfo: Optionally, additional information
    ///   - override: Override the user preference.
    func error(_ message: String,
               error: Error? = nil,
               userInfo: [String: Any]? = nil,
               override: Bool = false,
               _ file: StaticString = #file,
               _ function: StaticString = #function,
               _ line: UInt = #line) {
        #if DEBUG
        print("--------- ☠️ ERROR: \(String(describing: error)). \(message) --------- ")
        #endif
        guard Properties.errorLogging || override else {
            return
        }
        crashlytics.setCustomValue(message, forKey: "message")
        crashlytics.setCustomValue("error", forKey: "level")
        crashlytics.setCustomValue(file, forKey: "file")
        crashlytics.setCustomValue(function, forKey: "function")
        crashlytics.setCustomValue(Int32(line), forKey: "line")
        crashlytics.record(error: error ?? KeynError())
    }

    /// Submit an analytics event.
    /// - Parameters:
    ///   - event: The analytics event.
    ///   - properties: Additional properties
    ///   - override: Override the user preference.
    func analytics(_ event: AnalyticsEvent, properties: [AnalyticsEventProperty: Any]? = nil, override: Bool = false) {
        print("ℹ️ EVENT: \(event)")
        guard Properties.analyticsLogging || override else {
            return
        }
        amplitude.logEvent(event: event, properties: properties)
    }

}

struct KeynError: Error {}
