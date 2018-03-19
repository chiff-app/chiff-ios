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

extension String {
    public func longestCommonSubsequence(_ other: String) -> String {
        
        // Computes the length of the lcs using dynamic programming.
        // Output is a matrix of size (n+1)x(m+1), where matrix[x][y] is the length
        // of lcs between substring (0, x-1) of self and substring (0, y-1) of other.
        func lcsLength(_ other: String) -> [[Int]] {
            
            // Create matrix of size (n+1)x(m+1). The algorithm needs first row and
            // first column to be filled with 0.
            var matrix = [[Int]](repeating: [Int](repeating: 0, count: other.count+1), count: self.characters.count+1)
            
            for (i, selfChar) in self.enumerated() {
                for (j, otherChar) in other.enumerated() {
                    if otherChar == selfChar {
                        // Common char found, add 1 to highest lcs found so far.
                        matrix[i+1][j+1] = matrix[i][j] + 1
                    } else {
                        // Not a match, propagates highest lcs length found so far.
                        matrix[i+1][j+1] = max(matrix[i][j+1], matrix[i+1][j])
                    }
                }
            }
            
            // Due to propagation, lcs length is at matrix[n][m].
            return matrix
        }
        
        // Backtracks from matrix[n][m] to matrix[1][1] looking for chars that are
        // common to both strings.
        func backtrack(_ matrix: [[Int]]) -> String {
            var i = self.count
            var j = other.count
            
            // charInSequence is in sync with i so we can get self[i]
            var charInSequence = self.endIndex
            
            var lcs = String()
            
            while i >= 1 && j >= 1 {
                // Indicates propagation without change: no new char was added to lcs.
                if matrix[i][j] == matrix[i][j - 1] {
                    j -= 1
                }
                    // Indicates propagation without change: no new char was added to lcs.
                else if matrix[i][j] == matrix[i - 1][j] {
                    i -= 1
                    // As i was decremented, move back charInSequence.
                    charInSequence = self.index(before: charInSequence)
                }
                    // Value on the left and above are different than current cell.
                    // This means 1 was added to lcs length (line 17).
                else {
                    i -= 1
                    j -= 1
                    charInSequence = self.index(before: charInSequence)
                    
                    lcs.append(self[charInSequence])
                }
            }
            
            // Due to backtrack, chars were added in reverse order: reverse it back.
            // Append and reverse is faster than inserting at index 0.
            return String(lcs.reversed())
        }
        
        // Combine dynamic programming approach with backtrack to find the lcs.
        return backtrack(lcsLength(other))
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

    func pad(toSize: Int) -> String {
        var padded = self
        for _ in 0..<(toSize - self.count) {
            padded = "0" + padded
        }
        return padded
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

extension UIColor {
    convenience init(red: Int, green: Int, blue: Int) {
        assert(red >= 0 && red <= 255, "Invalid red component")
        assert(green >= 0 && green <= 255, "Invalid green component")
        assert(blue >= 0 && blue <= 255, "Invalid blue component")

        self.init(red: CGFloat(red) / 255.0, green: CGFloat(green) / 255.0, blue: CGFloat(blue) / 255.0, alpha: 1.0)
    }

    convenience init(rgb: Int) {
        self.init(
            red: (rgb >> 16) & 0xFF,
            green: (rgb >> 8) & 0xFF,
            blue: rgb & 0xFF
        )
    }
}

public extension UIImage {
    public convenience init?(color: UIColor, size: CGSize = CGSize(width: 1, height: 1)) {
        let rect = CGRect(origin: .zero, size: size)
        UIGraphicsBeginImageContextWithOptions(rect.size, false, 0.0)
        color.setFill()
        UIRectFill(rect)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        guard let cgImage = image?.cgImage else { return nil }
        self.init(cgImage: cgImage)
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


struct BrowserMessage: Codable {
    let s: Int?          // SiteID
    let r: BrowserMessageType
    let b: Int?          // browserTab
}

struct CredentialsResponse: Codable {
    let u: String       // Username
    let p: String      // Password
    let np: String?     // New password (for reset only! When registering p will be set)
    let b: Int
}

struct PushNotification {
    let sessionID : String
    let siteID: Int
    let browserTab: Int
    let requestType: BrowserMessageType
}

enum BrowserMessageType: Int, Codable {
    case pair
    case login
    case register
    case reset
    case end
}

enum KeyType: UInt64 {
    case passwordSeed, backupSeed
}
