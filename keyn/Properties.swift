//
//  Properties.swift
//  keyn
//
//  Created by bas on 22/03/2018.
//  Copyright © 2018 keyn. All rights reserved.
//

import Foundation

struct Properties {

    init() {}
    
    static let isDebug: Bool = {
        var debug = false
        #if DEBUG
            debug = true
        #endif
        return debug
    }()

    static let AWSPlaformApplicationArn = (
        sandbox: "arn:aws:sns:eu-central-1:589716660077:app/APNS_SANDBOX/Keyn",
        production: "arn:aws:sns:eu-central-1:589716660077:app/APNS/Keyn"
    )

    static let AWSSQSBaseUrl = "https://sqs.eu-central-1.amazonaws.com/589716660077/"
    
    static let keynApi = "ahqgqcn6le.execute-api.eu-central-1.amazonaws.com/test/"
    
    static let AWSSNSNotificationArn = (
        production: "arn:aws:sns:eu-central-1:589716660077:KeynNotifications",
        sandbox: "arn:aws:sns:eu-central-1:589716660077:KeynNotificationsSandbox"
    )
    
    static func isFirstLaunch() -> Bool {
        let hasBeenLaunchedBeforeFlag = "hasBeenLaunchedBeforeFlag"
        let isFirstLaunch = !UserDefaults.standard.bool(forKey: hasBeenLaunchedBeforeFlag)
        if (isFirstLaunch) {
            UserDefaults.standard.set(true, forKey: hasBeenLaunchedBeforeFlag)
            UserDefaults.standard.synchronize()
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




