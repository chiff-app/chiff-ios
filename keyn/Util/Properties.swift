/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import Foundation
import LocalAuthentication

struct Properties {

    init() {}

    enum Environment: String {
        case dev = "dev"
        case beta = "beta"
        case prod = "prod"

        var path: String {
            switch self {
            case .dev: return "dev"
            case .beta: return Properties.migrated ? "v1" : "beta"
            case .prod: return "v1"
            }
        }
    }

    static private let receivedNewsMessagesFlag = "receivedNewsMessagesFlag"
    static private let questionnaireDirPurgedFlag = "questionnaireDirPurged"
    static private let errorLoggingFlag = "errorLogging"
    static private let analyticsLoggingFlag = "analyticsLogging"
    static private let userIdFlag = "userID"
    static private let subscriptionExiryDateFlag = "subscriptionExiryDate"
    static private let subscriptionProductFlag = "subscriptionProduct"
    static private let accountCountFlag = "accountCount"
    static private let teamAccountCountFlag = "accountCount"
    static private let agreedWithTermsFlag = "agreedWithTerms"
    static private let firstPairingCompletedFlag = "firstPairingCompleted"
    static private let reloadAccountsFlag = "reloadAccountsFlag"
    static private let sortingPreferenceFlag = "sortingPreference"
    static private let hasBeenLaunchedBeforeFlag = "hasBeenLaunchedBeforeFlag" // IMPORTANT: If this flag is not present, all data will be deleted from Keychain on App startup!
    static private let lastRunVersionFlag = "lastRunVersionFlag"
    static private let migratedFlag = "migratedFlag"

    static var isFirstLaunch: Bool {
        let isFirstLaunch = !UserDefaults.standard.bool(forKey: hasBeenLaunchedBeforeFlag)
        if (isFirstLaunch) {
            UserDefaults.standard.set(true, forKey: hasBeenLaunchedBeforeFlag)
        }
        return isFirstLaunch
    }

    static func receivedNewsMessage(id: String) -> Bool {
        let ids = UserDefaults.standard.array(forKey: receivedNewsMessagesFlag) as? [String] ?? []
        return ids.contains(id)
    }

    static func addReceivedNewsMessage(id: String) {
        var ids = UserDefaults.standard.array(forKey: receivedNewsMessagesFlag) as? [String] ?? []
        ids.append(id)
        UserDefaults.standard.set(ids, forKey: receivedNewsMessagesFlag)
    }

    static var reloadAccounts: Bool {
        get { return UserDefaults.standard.bool(forKey: reloadAccountsFlag) }
        set { UserDefaults.standard.set(newValue, forKey: reloadAccountsFlag) }
    }
    static var firstPairingCompleted: Bool {
        get { return UserDefaults.standard.bool(forKey: firstPairingCompletedFlag) }
        set { UserDefaults.standard.set(newValue, forKey: firstPairingCompletedFlag) }
    }
    static var agreedWithTerms: Bool {
        get { return UserDefaults.standard.bool(forKey: agreedWithTermsFlag) }
        set { UserDefaults.standard.set(newValue, forKey: agreedWithTermsFlag) }
    }
    static var questionnaireDirPurged: Bool {
        get { return UserDefaults.standard.bool(forKey: questionnaireDirPurgedFlag) }
        set { UserDefaults.standard.set(newValue, forKey: questionnaireDirPurgedFlag) }
    }
    static var errorLogging: Bool {
        get { return environment == .beta || UserDefaults.standard.bool(forKey: errorLoggingFlag) }
        set { UserDefaults.standard.set(newValue, forKey: errorLoggingFlag) }
    }
    static var analyticsLogging: Bool {
        get { return environment == .beta || UserDefaults.standard.bool(forKey: analyticsLoggingFlag) }
        set {
            UserDefaults.standard.set(newValue, forKey: analyticsLoggingFlag)
            Logger.shared.setAnalyticsLogging(value: newValue)
        }
    }
    static var migrated: Bool {
        get { return environment == .beta && UserDefaults.standard.bool(forKey: migratedFlag) }
        set {
            guard environment == .beta else { return }
            UserDefaults.standard.set(newValue, forKey: migratedFlag)
        }
    }
    static var userId: String? {
        get { return UserDefaults.standard.string(forKey: userIdFlag) }
        set {
            Logger.shared.setUserId(userId: newValue)
            UserDefaults.standard.set(newValue, forKey: userIdFlag)
        }
    }
    static var sortingPreference: SortingValue {
        get { return SortingValue(rawValue: UserDefaults.standard.integer(forKey: sortingPreferenceFlag)) ?? SortingValue.alphabetically }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: sortingPreferenceFlag) }
    }

    static var isJailbroken = false
    static var subscriptionExiryDate: TimeInterval {
        get { return UserDefaults.standard.double(forKey: subscriptionExiryDateFlag) }
        set {
            UserDefaults.standard.set(newValue, forKey: subscriptionExiryDateFlag)
            NotificationCenter.default.postMain(name: .subscriptionUpdated, object: nil, userInfo: ["status": hasValidSubscription])
        }
    }
    static var subscriptionProduct: String? {
        get { return UserDefaults.standard.string(forKey: subscriptionProductFlag) }
        set { UserDefaults.standard.set(newValue, forKey: subscriptionProductFlag) }
    }
    static var hasValidSubscription: Bool {
        return true
//        return environment == .beta || TeamSession.count > 0 || subscriptionExiryDate > Date.now
    }
    static var accountCount: Int {
        get { return UserDefaults.standard.integer(forKey: accountCountFlag) }
        set { UserDefaults.standard.set(newValue, forKey: accountCountFlag) }
    }
    static func getSharedAccountCount(teamId: String) -> Int {
        if let data = UserDefaults.standard.dictionary(forKey: teamAccountCountFlag) as? [String: Int] {
            return data[teamId] ?? 0
        } else {
            return 0
        }
    }
    static func setSharedAccountCount(teamId: String, count: Int) {
        if var data = UserDefaults.standard.dictionary(forKey: teamAccountCountFlag) as? [String: Int] {
            data[teamId] = count
            UserDefaults.standard.set(data, forKey: teamAccountCountFlag)
        } else {
            UserDefaults.standard.set([teamId: count], forKey: teamAccountCountFlag)
        }
    }

    static var accountOverflow: Bool {
        return accountCount > accountCap
    }
    static var canAddAccount: Bool {
        return hasValidSubscription || accountCount < accountCap
    }

    static func purgePreferences() {
        UserDefaults.standard.removeObject(forKey: errorLoggingFlag)
        UserDefaults.standard.removeObject(forKey: analyticsLoggingFlag)
        UserDefaults.standard.removeObject(forKey: userIdFlag)
        UserDefaults.standard.removeObject(forKey: sortingPreferenceFlag)
        UserDefaults.standard.removeObject(forKey: migratedFlag)
//        UserDefaults.standard.removeObject(forKey: accountCountFlag)
//        UserDefaults.standard.removeObject(forKey: sessionCountFlag)
        // We're keeping: questionnaireDirPurgedFlag, subscriptionExiryDateFlag, subscriptionProductFlag, agreedWithTermsFlag, firstPairingCompletedFlag
    }

    static var deniedPushNotifications = false {
        didSet {
            if oldValue != deniedPushNotifications {
                Logger.shared.analytics(.notificationPermission, properties: [.value: !deniedPushNotifications])
            }
        }
    }
    
    static let isDebug: Bool = {
        var debug = false
        #if DEBUG
            debug = true
        #endif
        return debug
    }()

    static let environment: Environment = {
        if Properties.isDebug {
            return .dev
        } else if Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt" {
            return .beta
        } else {
            return .prod
        }
    }()

    static let version: String? = {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }()

    static let build: String? = {
        return Bundle.main.infoDictionary?["CFBundleVersion"] as? String
    }()

    static let hasFaceID: Bool = {
        if #available(iOS 11.0, *) {
            let context = LAContext()
            if context.canEvaluatePolicy(LAPolicy.deviceOwnerAuthenticationWithBiometrics, error: nil) {
                return context.biometryType == LABiometryType.faceID
            }
        }

        return false
    }()


    static let browsers = ["Chrome", "Edge", "Firefox", "Tor"]

    static let systems = ["Windows", "Mac OS", "Debian", "Ubuntu"]

    static let keynApi = "api.chiff.dev"
    
    static let accountCap = 8

    static let nudgeNotificationIdentifiers = [
        "io.keyn.keyn.first_nudge",
        "io.keyn.keyn.second_nudge",
        "io.keyn.keyn.third_nudge"
    ]

    static var endpoint: String? {
        guard let endpointData = try? Keychain.shared.get(id: KeyIdentifier.endpoint.identifier(for: .aws), service: .aws) else {
            return nil
        }
        return String(data: endpointData, encoding: .utf8)
    }

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

    static let PASTEBOARD_TIMEOUT = 60.0 // seconds

    static var firstLaunchTimestamp: Timestamp {
        #warning("TODO: Not accurate, should it be updated?")
        let installTimestamp = "installTimestamp"
        if let installDate = UserDefaults.standard.object(forKey: installTimestamp) as? Date {
            return installDate.millisSince1970
        } else {
            let date = Date()
            UserDefaults.standard.set(date, forKey: installTimestamp)
            return date.millisSince1970
        }
    }

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
