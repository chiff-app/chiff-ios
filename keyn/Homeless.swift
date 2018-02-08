//
//  Homeless.swift
//  keyn
//
//  Created by bas on 24/11/2017.
//  Copyright © 2017 keyn. All rights reserved.
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

extension UIApplication {

    var visibleViewController: UIViewController? {

        guard let rootViewController = keyWindow?.rootViewController else {
            return nil
        }

        return getVisibleViewController(rootViewController)
    }

    private func getVisibleViewController(_ rootViewController: UIViewController) -> UIViewController? {

        if let presentedViewController = rootViewController.presentedViewController {
            return getVisibleViewController(presentedViewController)
        }

        if let navigationController = rootViewController as? UINavigationController {
            return navigationController.visibleViewController
        }

        if let tabBarController = rootViewController as? UITabBarController {
            return tabBarController.selectedViewController
        }

        return rootViewController
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

extension String {
    func components(withLength length: Int) -> [String] {
        return stride(from: 0, to: self.count, by: length).map {
            let start = self.index(self.startIndex, offsetBy: $0)
            let end = self.index(start, offsetBy: length, limitedBy: self.endIndex) ?? self.endIndex
            return String(self[start..<end])
        }
    }
}

extension Data {
    struct HexEncodingOptions: OptionSet {
        let rawValue: Int
        static let upperCase = HexEncodingOptions(rawValue: 1 << 0)
    }

    func hexEncodedString(options: HexEncodingOptions = []) -> String {
        let format = options.contains(.upperCase) ? "%02hhX" : "%02hhx"
        return map { String(format: format, $0) }.joined()
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
struct PairingResponse: Codable {
    let sessionID: String
    let pubKey: String
    let sns: String
}

// MARK: hallo
struct CredentialsRequest: Codable {
    let s: String          // SiteID
    let r: RequestType
    let b: Int          // browserTab
}

struct CredentialsResponse: Codable {
    let u: String       // Username
    let p: String       // Password
    let b: Int
}

struct PushNotification {
    let sessionID : String
    let siteID: String // Wordt int
    let browserTab: Int
    let requestType: RequestType
}

enum RequestType: Int, Codable {
    case pair
    case login
    case registration
    case reset
}

enum KeyType {
    case passwordSeed, backupSeed
}
