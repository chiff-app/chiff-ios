//
//  Properties.swift
//  ChiffCore
//
//  Copyright: see LICENSE.md
//

import Foundation
import LocalAuthentication

public struct Properties {

    init() {}

    public enum Environment: String {
        case dev
        case staging
        case prod

        var path: String {
            if case .dev = self {
                return "dev"
            } else {
                return "v1"
            }
        }
        
        var host: String {
            return self == .dev ? "api.chiff.io" : "api.chiff.dev"
        }
        
        public var description: String {
            switch self {
            case .dev: return "development"
            case .staging: return "staging"
            case .prod: return "production"
            }
        }
    }

    private static let receivedNewsMessagesFlag = "receivedNewsMessagesFlag"
    private static let errorLoggingFlag = "errorLogging"
    private static let analyticsLoggingFlag = "analyticsLogging"
    private static let userIdFlag = "userID"
    private static let accountCountFlag = "accountCount"
    private static let teamAccountCountFlag = "accountCount"
    private static let agreedWithTermsFlag = "agreedWithTerms"
    private static let acknowledgedDeprecationFlag = "acknowledgedDeprecation"
    private static let firstPairingCompletedFlag = "firstPairingCompleted"
    private static let reloadAccountsFlag = "reloadAccountsFlag"
    private static let hasBeenLaunchedBeforeFlag = "hasBeenLaunchedBeforeFlag" // IMPORTANT: If this flag is not present, all data will be deleted from Keychain on App startup!
    private static let lastRunVersionFlag = "lastRunVersionFlag"
    private static let keychainVersionFlag = "keychainVersionFlag"
    private static let attestationKeyIDFlag = "attestationKeyIDFlag"
    private static let extraVerificationFlag = "extraVerificationFlag"

    public static let latestKeychainVersion = 3
    static let termsOfUseVersion = 2

    /// Whether this is the first time the app is launched.
    public static var isFirstLaunch: Bool {
        let isFirstLaunch = !UserDefaults.standard.bool(forKey: hasBeenLaunchedBeforeFlag)
        if isFirstLaunch {
            UserDefaults.standard.set(true, forKey: hasBeenLaunchedBeforeFlag)
        }
        return isFirstLaunch
    }

    /// Whether a news message has already been received.
    public static func receivedNewsMessage(id: String) -> Bool {
        let ids = UserDefaults.standard.array(forKey: receivedNewsMessagesFlag) as? [String] ?? []
        return ids.contains(id)
    }

    /// Save a news message id so it won't be shown again.
    public static func addReceivedNewsMessage(id: String) {
        var ids = UserDefaults.standard.array(forKey: receivedNewsMessagesFlag) as? [String] ?? []
        ids.append(id)
        UserDefaults.standard.set(ids, forKey: receivedNewsMessagesFlag)
    }

    /// Flag to indicate whether accounts should be reload into the identity store.
    public static var reloadAccounts: Bool {
        get { return UserDefaults.standard.bool(forKey: reloadAccountsFlag) }
        set { UserDefaults.standard.set(newValue, forKey: reloadAccountsFlag) }
    }

    /// Whether the first pairing has been completed.
    public static var firstPairingCompleted: Bool {
        get { return UserDefaults.standard.bool(forKey: firstPairingCompletedFlag) }
        set { UserDefaults.standard.set(newValue, forKey: firstPairingCompletedFlag) }
    }

    /// Whether the latest version of the terms have been notified.
    public static var notifiedLatestTerms: Bool {
        get { return UserDefaults.standard.integer(forKey: agreedWithTermsFlag) >= termsOfUseVersion }
        set { if newValue {
                UserDefaults.standard.set(termsOfUseVersion, forKey: agreedWithTermsFlag)
            }
        }
    }

    /// Whether the user agreed with the terms.
    public static var agreedWithTerms: Bool {
        get { return UserDefaults.standard.integer(forKey: agreedWithTermsFlag) > 0 }
        set { if newValue {
                UserDefaults.standard.set(termsOfUseVersion, forKey: agreedWithTermsFlag)
            }
        }
    }
    
    /// Whether the user acknowledged the deprecation warning.
    public static var acknowledgedDeprecation: Bool {
        get { return UserDefaults.standard.bool(forKey: acknowledgedDeprecationFlag) }
        set { UserDefaults.standard.set(newValue, forKey: acknowledgedDeprecationFlag) }
    }

    /// Whether the user allows error logging.
    public static var errorLogging: Bool {
        get { return environment == .staging || UserDefaults.group.bool(forKey: errorLoggingFlag) }
        set {
            UserDefaults.group.set(newValue, forKey: errorLoggingFlag)
            Logger.shared.setErrorLogging(value: newValue)
        }
    }

    /// Wheter the user allows analytics messages.
    public static var analyticsLogging: Bool {
        get { return environment == .staging || UserDefaults.group.bool(forKey: analyticsLoggingFlag) }
        set {
            UserDefaults.group.set(newValue, forKey: analyticsLoggingFlag)
            Logger.shared.setAnalyticsLogging(value: newValue)
        }
    }

    /// The version of this keychain
    public static var currentKeychainVersion: Int {
        get { UserDefaults.standard.integer(forKey: keychainVersionFlag) }
        set { UserDefaults.standard.set(newValue, forKey: keychainVersionFlag) }
    }

    /// The user ID for this user.
    public static var userId: String? {
        get { return UserDefaults.group.string(forKey: userIdFlag) }
        set {
            Logger.shared.setUserId(userId: newValue)
            UserDefaults.group.set(newValue, forKey: userIdFlag)
        }
    }

    /// Whether this phone has been detected as being jailbroken.
    public static var isJailbroken = false

    /// The number of accounts, shadowed because Keychain access is authenticated.
    public static var accountCount: Int {
        get { return UserDefaults.group.integer(forKey: accountCountFlag) }
        set { UserDefaults.group.set(newValue, forKey: accountCountFlag) }
    }

    /// The number of shared accounts, shadowed because Keychain access is authenticated.
    static func getSharedAccountCount(teamId: String) -> Int {
        if let data = UserDefaults.group.dictionary(forKey: teamAccountCountFlag) as? [String: Int] {
            return data[teamId] ?? 0
        } else {
            return 0
        }
    }

    /// Set number of shared accounts.
    static func setSharedAccountCount(teamId: String, count: Int) {
        if var data = UserDefaults.group.dictionary(forKey: teamAccountCountFlag) as? [String: Int] {
            data[teamId] = count
            UserDefaults.group.set(data, forKey: teamAccountCountFlag)
        } else {
            UserDefaults.group.set([teamId: count], forKey: teamAccountCountFlag)
        }
    }

    /// The WebAuthn (Apple) attestation keyID.
    static var attestationKeyID: String? {
        get { return UserDefaults.standard.string(forKey: attestationKeyIDFlag) }
        set { UserDefaults.standard.set(newValue, forKey: attestationKeyIDFlag) }
    }

    /// Remove relevant user preferences.
    public static func purgePreferences() {
        UserDefaults.group.removeObject(forKey: errorLoggingFlag)
        UserDefaults.group.removeObject(forKey: analyticsLoggingFlag)
        UserDefaults.group.removeObject(forKey: userIdFlag)
        UserDefaults.group.removeObject(forKey: teamAccountCountFlag)
        UserDefaults.group.removeObject(forKey: accountCountFlag)

        // Don't purge keychainVersion here, since new / recovered seed will be saved with latest version.
    }

    /// Whether this user denied push notifications.
    public static var deniedPushNotifications = false {
        didSet {
            if oldValue != deniedPushNotifications {
                Logger.shared.analytics(.notificationPermission, properties: [.value: !deniedPushNotifications])
            }
        }
    }

    /// Whether this is a debug session.
    static let isDebug: Bool = {
        var debug = false
        #if DEBUG
            debug = true
        #endif
        return debug
    }()

    /// The environment.
    public static let environment: Environment = {
        if Properties.isDebug {
            return .dev
        } else if Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt" {
            return .staging
        } else {
            return .prod
        }
    }()

    /// The app's version.
    public static let version: String? = {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }()

    /// The app's build.
    public static let build: String? = {
        return Bundle.main.infoDictionary?["CFBundleVersion"] as? String
    }()

    /// Whether this device supports FaceID.
    public static let hasFaceID: Bool = {
        if #available(iOS 11.0, *) {
            let context = LAContext()
            if context.canEvaluatePolicy(LAPolicy.deviceOwnerAuthenticationWithBiometrics, error: nil) {
                return context.biometryType == LABiometryType.faceID
            }
        }

        return false
    }()

    /// The AWS ARN endpoint for this device for push notifications.
    public static var endpoint: String? {
        guard let endpointData = try? Keychain.shared.get(id: KeyIdentifier.endpoint.identifier(for: .aws), service: .aws) else {
            return nil
        }
        return String(data: endpointData, encoding: .utf8)
    }

    /// The timestamp at which the app was firsted launched.
    public static var firstLaunchTimestamp: Timestamp {
        let installTimestamp = "installTimestamp"
        if let installDate = UserDefaults.standard.object(forKey: installTimestamp) as? Date {
            return installDate.millisSince1970
        } else {
            let date = Date()
            UserDefaults.standard.set(date, forKey: installTimestamp)
            return date.millisSince1970
        }
    }

    /// Whether the app has just been upgraded.
    static var isUpgraded: Bool {
        guard let lastRunVersion = UserDefaults.standard.string(forKey: lastRunVersionFlag) else {
            UserDefaults.standard.set(Properties.version, forKey: lastRunVersionFlag)
            return false
        }
        guard let currentVersion = Properties.version else {
            return false
        }
        defer {
            UserDefaults.standard.set(Properties.version, forKey: lastRunVersionFlag)
        }
        return currentVersion != lastRunVersion
    }
    
    /// Whether extra verification has been enabled
    public static var extraVerification: Bool {
        get { return UserDefaults.standard.bool(forKey: extraVerificationFlag)  }
        set { UserDefaults.standard.setValue(newValue, forKey: extraVerificationFlag) }
    }

    public static func migrateToAppGroup() {
        guard UserDefaults.group.object(forKey: userIdFlag) == nil else {
            return
        }
        UserDefaults.group.setValue(UserDefaults.standard.string(forKey: userIdFlag), forKey: userIdFlag)
        UserDefaults.group.setValue(UserDefaults.standard.dictionary(forKey: teamAccountCountFlag), forKey: teamAccountCountFlag)
        UserDefaults.group.setValue(UserDefaults.standard.integer(forKey: accountCountFlag), forKey: accountCountFlag)
        UserDefaults.group.setValue(UserDefaults.standard.bool(forKey: analyticsLoggingFlag), forKey: analyticsLoggingFlag)
        UserDefaults.group.setValue(UserDefaults.standard.bool(forKey: errorLoggingFlag), forKey: errorLoggingFlag)
    }

}
