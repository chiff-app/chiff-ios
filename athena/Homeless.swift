//
//  Homeless.swift
//  athena
//
//  Created by bas on 24/11/2017.
//  Copyright © 2017 athena. All rights reserved.
//

import Foundation
import UIKit

// Extension for UIViewController that return visible view controller if it is a navigationController
extension UIViewController {
    var contents: UIViewController {
        if let navigationController = self as? UINavigationController {
            return navigationController.visibleViewController ?? self
        } else {
            return self
        }
    }
}

extension String {
    func hash() throws -> String {
        return try Crypto.sharedInstance.hash(self)
    }
}


// Extension for URL that return parameters as dict
extension URL {
    public var queryParameters: [String: String]? {
        guard let components = URLComponents(url: self, resolvingAgainstBaseURL: true), let queryItems = components.queryItems else {
            return nil
        }

        var parameters = [String: String]()
        for item in queryItems {
            parameters[item.name] = item.value
        }

        return parameters
    }
}

// Used by Account and Site
struct PasswordRestrictions: Codable {
    let length: Int
    let characters: [Characters]

    enum Characters: String, Codable {
        case lower
        case upper
        case numbers
        case symbols
    }
    

}

// Used by SessionManager
struct PasswordMessage: Codable {
    let sessionID: String
    let pubKey: String
    let sns: String
    let creds: Credentials
}

struct Credentials: Codable {
    let siteID: String
    let username: String
    let password: String
}


