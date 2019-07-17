/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import Foundation

enum InfoNotificationStatus: Int {
    case notDecided
    case yes
    case no
}

struct Properties {

    init() {}

    enum Environment: String {
        case dev = "dev"
        case beta = "beta"
        case prod = "v1"
    }

    static private let questionnaireDirPurgedFlag = "questionnaireDirPurged"
    static private let errorLoggingFlag = "errorLogging"
    static private let analyticsLoggingFlag = "analyticsLogging"
    static private let infoNotificationsFlag = "infoNotifications"
    static private let userIdFlag = "userID"

    static var questionnaireDirPurged: Bool {
        get { return UserDefaults.standard.bool(forKey: questionnaireDirPurgedFlag) }
        set { UserDefaults.standard.set(newValue, forKey: questionnaireDirPurgedFlag) }
    }
    static var errorLogging: Bool {
        get { return environment == .beta ? true : UserDefaults.standard.bool(forKey: errorLoggingFlag) }
        set { UserDefaults.standard.set(newValue, forKey: errorLoggingFlag) }
    }
    static var analyticsLogging: Bool {
        get { return environment == .beta ? true : UserDefaults.standard.bool(forKey: analyticsLoggingFlag) }
        set { UserDefaults.standard.set(newValue, forKey: analyticsLoggingFlag) }
    }
    static var infoNotifications: InfoNotificationStatus {
        get { return InfoNotificationStatus(rawValue: UserDefaults.standard.integer(forKey: infoNotificationsFlag)) ?? InfoNotificationStatus.notDecided }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: infoNotificationsFlag) }
    }
    static var userId: String? {
        get { return UserDefaults.standard.string(forKey: userIdFlag) }
        set {
            Logger.shared.setUserId(userId: newValue)
            UserDefaults.standard.set(newValue, forKey: userIdFlag)
        }
    }

    static func purgePreferences() {
        UserDefaults.standard.removeObject(forKey: errorLoggingFlag)
        UserDefaults.standard.removeObject(forKey: analyticsLoggingFlag)
        UserDefaults.standard.removeObject(forKey: infoNotificationsFlag)
    }

    static var deniedPushNotifications = false
    
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

    static let browsers = ["Chrome", "Edge", "Firefox", "Tor"]

    static let systems = ["Windows", "Mac OS", "Debian", "Ubuntu"]

    static let keynApi = "api.keyn.app"
    
    static let logzioToken = "AZQteKGtxvKchdLHLomWvbIpELYAWVHB"
    
    static let AWSSNSNotificationArn = (
        production: "arn:aws:sns:eu-central-1:589716660077:KeynNotifications",
        sandbox: "arn:aws:sns:eu-central-1:589716660077:KeynNotificationsSandbox"
    )

    static var notificationTopic: String {
        switch environment {
        case .dev:
            return AWSSNSNotificationArn.sandbox
        case .beta, .prod:
            return AWSSNSNotificationArn.production
        }
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

    static func isFirstLaunch() -> Bool {
        let hasBeenLaunchedBeforeFlag = "hasBeenLaunchedBeforeFlag"
        let isFirstLaunch = !UserDefaults.standard.bool(forKey: hasBeenLaunchedBeforeFlag)

        if (isFirstLaunch) {
            UserDefaults.standard.set(true, forKey: hasBeenLaunchedBeforeFlag)
        }

        return isFirstLaunch
    }

    static func installTimestamp() -> Date? {
        let installTimestamp = "installTimestamp"

        if let installDate = UserDefaults.standard.object(forKey: installTimestamp) as? Date {
            return installDate
        } else {
            let date = Date()
            UserDefaults.standard.set(date, forKey: installTimestamp)
            return nil
        }
    }

}
