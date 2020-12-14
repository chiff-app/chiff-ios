//
//  Properties.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import Foundation
import LocalAuthentication

struct Properties {

    init() {}

    enum Environment: String {
        case dev
        case beta
        case prod

        var path: String {
            switch self {
            case .dev: return "dev"
            case .beta: return Properties.migrated ? "v1" : "beta"
            case .prod: return "v1"
            }
        }
    }

    private static let receivedNewsMessagesFlag = "receivedNewsMessagesFlag"
    private static let errorLoggingFlag = "errorLogging"
    private static let analyticsLoggingFlag = "analyticsLogging"
    private static let userIdFlag = "userID"
    private static let subscriptionExiryDateFlag = "subscriptionExiryDate"
    private static let subscriptionProductFlag = "subscriptionProduct"
    private static let accountCountFlag = "accountCount"
    private static let teamAccountCountFlag = "accountCount"
    private static let agreedWithTermsFlag = "agreedWithTerms"
    private static let firstPairingCompletedFlag = "firstPairingCompleted"
    private static let reloadAccountsFlag = "reloadAccountsFlag"
    private static let sortingPreferenceFlag = "sortingPreference"
    private static let hasBeenLaunchedBeforeFlag = "hasBeenLaunchedBeforeFlag" // IMPORTANT: If this flag is not present, all data will be deleted from Keychain on App startup!
    private static let lastRunVersionFlag = "lastRunVersionFlag"
    private static let migratedFlag = "migratedFlag"

    static let termsOfUseVersion = 2

    /// Whether this is the first time the app is launched.
    static var isFirstLaunch: Bool {
        let isFirstLaunch = !UserDefaults.standard.bool(forKey: hasBeenLaunchedBeforeFlag)
        if isFirstLaunch {
            UserDefaults.standard.set(true, forKey: hasBeenLaunchedBeforeFlag)
        }
        return isFirstLaunch
    }

    /// Whether a news message has already been received.
    static func receivedNewsMessage(id: String) -> Bool {
        let ids = UserDefaults.standard.array(forKey: receivedNewsMessagesFlag) as? [String] ?? []
        return ids.contains(id)
    }

    /// Save a news message id so it won't be shown again.
    static func addReceivedNewsMessage(id: String) {
        var ids = UserDefaults.standard.array(forKey: receivedNewsMessagesFlag) as? [String] ?? []
        ids.append(id)
        UserDefaults.standard.set(ids, forKey: receivedNewsMessagesFlag)
    }

    /// Flag to indicate whether accounts should be reload into the identity store.
    static var reloadAccounts: Bool {
        get { return UserDefaults.standard.bool(forKey: reloadAccountsFlag) }
        set { UserDefaults.standard.set(newValue, forKey: reloadAccountsFlag) }
    }

    /// Whether the first pairing has been completed.
    static var firstPairingCompleted: Bool {
        get { return UserDefaults.standard.bool(forKey: firstPairingCompletedFlag) }
        set { UserDefaults.standard.set(newValue, forKey: firstPairingCompletedFlag) }
    }

    /// Whether the latest version of the terms have been notified.
    static var notifiedLatestTerms: Bool {
        get { return UserDefaults.standard.integer(forKey: agreedWithTermsFlag) >= termsOfUseVersion }
        set { if newValue {
                UserDefaults.standard.set(termsOfUseVersion, forKey: agreedWithTermsFlag)
            }
        }
    }

    /// Whether the user agreed with the terms.
    static var agreedWithTerms: Bool {
        get { return UserDefaults.standard.integer(forKey: agreedWithTermsFlag) > 0 }
        set { if newValue {
                UserDefaults.standard.set(termsOfUseVersion, forKey: agreedWithTermsFlag)
            }
        }
    }

    /// Whether the user allows error logging.
    static var errorLogging: Bool {
        get { return environment == .beta || UserDefaults.standard.bool(forKey: errorLoggingFlag) }
        set { UserDefaults.standard.set(newValue, forKey: errorLoggingFlag) }
    }


    /// Wheter the user allows analytics messages.
    static var analyticsLogging: Bool {
        get { return environment == .beta || UserDefaults.standard.bool(forKey: analyticsLoggingFlag) }
        set {
            UserDefaults.standard.set(newValue, forKey: analyticsLoggingFlag)
            Logger.shared.setAnalyticsLogging(value: newValue)
        }
    }

    /// Whether the beta user been migrated to production.
    static var migrated: Bool {
        get { return environment == .beta && UserDefaults.standard.bool(forKey: migratedFlag) }
        set {
            guard environment == .beta else { return }
            UserDefaults.standard.set(newValue, forKey: migratedFlag)
        }
    }

    /// The user ID for this user.
    static var userId: String? {
        get { return UserDefaults.standard.string(forKey: userIdFlag) }
        set {
            Logger.shared.setUserId(userId: newValue)
            UserDefaults.standard.set(newValue, forKey: userIdFlag)
        }
    }

    /// The sorting preference of the accounts.
    static var sortingPreference: SortingValue {
        get { return SortingValue(rawValue: UserDefaults.standard.integer(forKey: sortingPreferenceFlag)) ?? SortingValue.alphabetically }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: sortingPreferenceFlag) }
    }

    /// Whether this phone has been detected as being jailbroken.
    static var isJailbroken = false


    /// The number of accounts, shadowed because Keychain access is authenticated.
    static var accountCount: Int {
        get { return UserDefaults.standard.integer(forKey: accountCountFlag) }
        set { UserDefaults.standard.set(newValue, forKey: accountCountFlag) }
    }

    /// The number of shared accounts, shadowed because Keychain access is authenticated.
    static func getSharedAccountCount(teamId: String) -> Int {
        if let data = UserDefaults.standard.dictionary(forKey: teamAccountCountFlag) as? [String: Int] {
            return data[teamId] ?? 0
        } else {
            return 0
        }
    }

    /// Set number of shared accounts.
    static func setSharedAccountCount(teamId: String, count: Int) {
        if var data = UserDefaults.standard.dictionary(forKey: teamAccountCountFlag) as? [String: Int] {
            data[teamId] = count
            UserDefaults.standard.set(data, forKey: teamAccountCountFlag)
        } else {
            UserDefaults.standard.set([teamId: count], forKey: teamAccountCountFlag)
        }
    }

    /// Remove relevant user preferences.
    static func purgePreferences() {
        UserDefaults.standard.removeObject(forKey: errorLoggingFlag)
        UserDefaults.standard.removeObject(forKey: analyticsLoggingFlag)
        UserDefaults.standard.removeObject(forKey: userIdFlag)
        UserDefaults.standard.removeObject(forKey: sortingPreferenceFlag)
        UserDefaults.standard.removeObject(forKey: migratedFlag)
    }


    /// Whether this user denied push notifications.
    static var deniedPushNotifications = false {
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
    static let environment: Environment = {
        if Properties.isDebug {
            return .dev
        } else if Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt" {
            return .beta
        } else {
            return .prod
        }
    }()

    /// The app's version.
    static let version: String? = {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }()

    /// The app's build.
    static let build: String? = {
        return Bundle.main.infoDictionary?["CFBundleVersion"] as? String
    }()

    /// Whether this device supports FaceID.
    static let hasFaceID: Bool = {
        if #available(iOS 11.0, *) {
            let context = LAContext()
            if context.canEvaluatePolicy(LAPolicy.deviceOwnerAuthenticationWithBiometrics, error: nil) {
                return context.biometryType == LABiometryType.faceID
            }
        }

        return false
    }()

    /// The API path.
    static let keynApi = "api.chiff.dev"

    /// Notification identifiers nudges.
    static let nudgeNotificationIdentifiers = [
        "io.keyn.keyn.first_nudge",
        "io.keyn.keyn.second_nudge",
        "io.keyn.keyn.third_nudge"
    ]

    /// The AWS ARN endpoint for this device for push notifications.
    static var endpoint: String? {
        guard let endpointData = try? Keychain.shared.get(id: KeyIdentifier.endpoint.identifier(for: .aws), service: .aws) else {
            return nil
        }
        return String(data: endpointData, encoding: .utf8)
    }

    /// The token for amplitude.
    static var amplitudeToken: String {
        switch environment {
        case .dev:
            return "a6c7cba5e56ef0084e4b61a930a13c84"
        case .beta:
            return "1d56fb0765c71d09e73b68119cfab32d"
        case .prod:
            return "081d54cf687bdf40799532a854b9a9b6"
        }
    }

    /// The number of seconds after which the pasteboard should be cleared.
    static let pasteboardTimeout = 60.0 // seconds

    /// The timestamp at which the app was firsted launched.
    static var firstLaunchTimestamp: Timestamp {
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

}
