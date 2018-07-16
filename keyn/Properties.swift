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

    static var AWSPlaformApplicationArn = (
        sandbox: "arn:aws:sns:eu-central-1:589716660077:app/APNS_SANDBOX/Keyn",
        production: "arn:aws:sns:eu-central-1:589716660077:app/APNS/Keyn"
    )

    static let AWSSQSBaseUrl = "https://sqs.eu-central-1.amazonaws.com/589716660077/"
    
    static func isFirstLaunch() -> Bool {
        let hasBeenLaunchedBeforeFlag = "hasBeenLaunchedBeforeFlag"
        let isFirstLaunch = !UserDefaults.standard.bool(forKey: hasBeenLaunchedBeforeFlag)
        if (isFirstLaunch) {
            UserDefaults.standard.set(true, forKey: hasBeenLaunchedBeforeFlag)
            UserDefaults.standard.synchronize()
        }
        return isFirstLaunch
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




