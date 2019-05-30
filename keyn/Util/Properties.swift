/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import Foundation

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

    static var questionnaireDirPurged: Bool {
        get { return UserDefaults.standard.bool(forKey: questionnaireDirPurgedFlag) }
        set { UserDefaults.standard.set(true, forKey: questionnaireDirPurgedFlag) }
    }
    static var errorLogging: Bool {
        get { return UserDefaults.standard.bool(forKey: errorLoggingFlag) }
        set { UserDefaults.standard.set(true, forKey: errorLoggingFlag) }
    }
    static var analyticsLogging: Bool {
        get { return UserDefaults.standard.bool(forKey: analyticsLoggingFlag) }
        set { UserDefaults.standard.set(true, forKey: analyticsLoggingFlag) }
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

    static func userID() -> String {
        if let userID = UserDefaults.standard.object(forKey: "userID") as? String {
            return userID
        } else {
            let userID = NSUUID().uuidString
            UserDefaults.standard.set(userID, forKey: "userID")
            return userID
        }
    }

}
