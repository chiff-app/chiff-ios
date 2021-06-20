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

    private var crashlytics: Crashlytics {
        return Crashlytics.crashlytics()
    }
    private var amplitude: Amplitude {
        return Amplitude.instance()
    }

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
        crashlytics.setCrashlyticsCollectionEnabled(value)
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
        submitError(message: message, error: error, type: "warning", file: file.description, line: line.description, function: function.description)
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
        submitError(message: message, error: error, type: "error", file: file.description, line: line.description, function: function.description)
    }

    private func submitError(message: String, error: Error?, type: String, file: String, line: String, function: String) {
        DispatchQueue.global(qos: .default).async {
            do {
                let data: [String: Any] = [
                    "message": message,
                    "error": (error != nil ? String(describing: error!) : nil) as Any,
                    "log_type": "error",
                    "version": Properties.version as Any,
                    "environment": Properties.environment.rawValue,
                    "device": "IOS",
                    "fileName": file,
                    "function": function,
                    "line": line,
                    "userID": Properties.userId as Any
                ]
                let jsonData = try JSONSerialization.data(withJSONObject: data, options: [])
                API.shared.request(path: "logs", method: .post, signature: nil, body: jsonData, parameters: nil).catch { err in
                    print("Error uploading error data: \(err)")
                }
            } catch let err {
                print("Error uploading error data: \(err)")
            }
        }
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
