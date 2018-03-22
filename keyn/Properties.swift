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


}




