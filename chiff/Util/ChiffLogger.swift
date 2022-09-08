//
//  Logger.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import Foundation
import Amplitude
import ChiffCore
import Sentry

struct ChiffLogger: LoggerProtocol {

    private var amplitude: Amplitude {
        return Amplitude.instance()
    }
    private let scrubbingRegex = try! NSRegularExpression(pattern: "privKey|private|password|username|keyPair|keypair|sharedKey|sharedKeypair|seed|accounts|order|signingKeypair|newPassword|code|pin|organisationKey|passwordSeed|encryptionKey|passwordOffset|passwordIndex|notes|tokenSecret|tokenURL|oldSeeds|backupKey|passwordKey|pairingKeyPair|sharedKeyKeyPair|pairing|allowCredentials|userHandle|challenge|displayName|\"p\":|\"y\":|\"c\":|\"u\":|\"o\":|\"h\":|\"np\":")
//    private var scrubbingRegex = /privKey|private|password|username|keyPair|keypair|sharedKey|sharedKeypair|seed|accounts|order|signingKeypair|newPassword|code|pin|organisationKey|passwordSeed|encryptionKey|passwordOffset|passwordIndex|notes|tokenSecret|tokenURL|oldSeeds|backupKey|passwordKey|pairingKeyPair|sharedKeyKeyPair|pairing|allowCredentials|userHandle|challenge|displayName|"p":|"y":|"c":|"u":|"o":|"h":|"np":/

    init() {
        startSentry()
        amplitude.initializeApiKey(Properties.amplitudeToken)
        amplitude.set(userProperties: [
            .accountCount: Properties.accountCount,
            .pairingCount: BrowserSession.count,
            .backupCompleted: Seed.paperBackupCompleted
        ])
        if let userId = Properties.userId {
            let user = User()
            user.userId = userId
            SentrySDK.setUser(user)
            setUserId(userId: userId)
        }
    }
    
    func startSentry() {
        SentrySDK.start { options in
            options.dsn = Properties.sentryDsn
            options.debug = Properties.environment == Properties.Environment.dev
            if let version = Properties.version {
                if let build = Properties.build {
                    options.releaseName = "chiff-ios@\(version)+\(build)"
                } else {
                    options.releaseName = "chiff-ios@\(version)"
                }
            }
            options.environment = Properties.environment.description
            options.attachStacktrace = true
            options.attachScreenshot = false
            options.attachViewHierarchy = false
            options.sendClientReports = false
            options.enableSwizzling = false
            
            options.integrations = Sentry.Options.defaultIntegrations().filter { $0 != "SentryAutoBreadcrumbTrackingIntegration" }
            
            // Disable breadcrumbs
            options.beforeBreadcrumb = { _ in
                return nil
            }
            options.beforeSend = { event in
                guard Properties.errorLogging || event.message?.formatted == "User feedback" else {
                    return nil
                }
                if let exceptions = event.exceptions {
                    for (index, exception) in exceptions.enumerated() {
                        if self.scrubbingRegex.numberOfMatches(in: exception.value, range: NSMakeRange(0, exception.value.count)) > 0 {
                            event.exceptions![index] = Exception(value: "<REDACTED>", type: exception.type)
                        }
                    }
                }
                if let message = event.message {
                    if self.scrubbingRegex.numberOfMatches(in: message.formatted, range: NSMakeRange(0, message.formatted.count)) > 0 {
                        event.message = SentryMessage(formatted: "<REDACTED>")
                    }
                }
                return event
            }
            
            // Set tracesSampleRate to 1.0 to capture 100% of transactions for performance monitoring.
            // We recommend adjusting this value in production.
            options.tracesSampleRate = 0.0
        }
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
        return
    }

    /// Set the user id for analytics and error logging.
    /// - Parameter userId: The user id.
    func setUserId(userId: String?) {
        if let userId = userId {
            let user = User()
            user.userId = userId
            SentrySDK.setUser(user)
            amplitude.setUserId(userId, startNewSession: false)
        } else {
            SentrySDK.setUser(nil)
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
        if let error = error {
            let event = Event(error: error)
            event.message = SentryMessage(formatted: message)
            event.level = .warning
            SentrySDK.capture(event: event)
        } else {
            let event = Event(level: .warning)
            event.message = SentryMessage(formatted: message)
            SentrySDK.capture(event: event)
        }
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
        if let error = error {
            let event = Event(error: error)
            event.message = SentryMessage(formatted: message)
            SentrySDK.capture(event: event)
        } else {
            SentrySDK.capture(message: message)
        }
    }
    
    
    /// Send feedback to Sentry
    /// - Parameters:
    ///   - message: The feedback message
    ///   - name: The user's name
    ///   - email: The user's email address
    func feedback(message: String, name: String?, email: String?) {
        let eventId = SentrySDK.capture(message: "User feedback")

        let userFeedback = UserFeedback(eventId: eventId)
        userFeedback.comments = message
        if let email = email {
            userFeedback.email = email
        }
        if let name = name {
            userFeedback.name = name
        }
        SentrySDK.capture(userFeedback: userFeedback)
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
