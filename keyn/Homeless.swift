/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import Foundation
import UIKit
import Sodium
import JustLog
import CommonCrypto

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

extension Int {
    func mod(_ n: Int) -> Int {
        return (self % n + n) % n
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
    func hash() -> String {
        do {
            let hash = try Crypto.shared.hash(self)
            return hash
        } catch {
            Logger.shared.error("Could not create hash.", error: error as NSError)
            fatalError("Could not create hash.")
        }
    }
    
    func sha1() -> String {
        let data = self.data(using: String.Encoding.utf8)!
        var digest = [UInt8](repeating: 0, count:Int(CC_SHA1_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA1($0, CC_LONG(data.count), &digest)
        }
        let hexBytes = digest.map { String(format: "%02hhx", $0) }
        return hexBytes.joined()
    }
    
    func sha256() -> String {
        let data = self.data(using: String.Encoding.utf8)!
        var digest = [UInt8](repeating: 0, count:Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0, CC_LONG(data.count), &digest)
        }
        let hexBytes = digest.map { String(format: "%02hhx", $0) }
        return hexBytes.joined()
    }
    
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
    
    var lines: [String] {
        var result: [String] = []
        enumerateLines { line, _ in result.append(line) }
        return result
    }
}

extension Notification.Name {
    static let passwordChangeConfirmation = Notification.Name("PasswordChangeConfirmation")
    static let sessionStarted = Notification.Name("SessionStarted")
    static let sessionEnded = Notification.Name("SessionEnded")
    static let accountAdded = Notification.Name("AccountAdded")
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

extension CALayer {
    func addBorder(edge: UIRectEdge, color: UIColor, thickness: CGFloat) {
        let border = CALayer()
        switch edge {
        case .top:
            border.frame = CGRect(x: 0, y: 0, width: frame.width, height: thickness)
        case .bottom:
            border.frame = CGRect(x: 0, y: frame.height - thickness, width: frame.width, height: thickness)
        case .left:
            border.frame = CGRect(x: 0, y: 0, width: thickness, height: frame.height)
        case .right:
            border.frame = CGRect(x: frame.width - thickness, y: 0, width: thickness, height: frame.height)
        default:
            break
        }
        
        border.backgroundColor = color.cgColor;
        addSublayer(border)
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
    
    var bytes: Bytes { return Bytes(self) }
}

extension Array where Element == UInt8 {
    public var data: Data {
        return Data(bytes: self)
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

extension UIImage {
    convenience init?(color: UIColor, size: CGSize = CGSize(width: 1, height: 1)) {
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

@IBDesignable
class FormTextField: UITextField {
    @IBInspectable var inset: CGFloat = 0
    
    override func textRect(forBounds bounds: CGRect) -> CGRect {
        return bounds.insetBy(dx: inset, dy: inset)
    }
    
    override func editingRect(forBounds bounds: CGRect) -> CGRect {
        return textRect(forBounds: bounds)
    }
}

enum AnalyticsMessage: String {
    case install = "INSTALL"
    case seedCreated = "SEED_CREATED"
    case update = "UPDATE" // TODO
    case iosUpdate = "IOS_UPDATE" // TODO
    case pairResponse = "PAIR_RESPONSE"
    case loginResponse = "LOGIN_RESPONSE"
    case fillResponse = "FILL_PASSWORD_RESPONSE"
    case addAndChange = "ADDANDCHANGE"
    case passwordChange = "PASSWORD_CHANGE"
    case addResponse = "ADD_RESPONSE"
    case registrationResponse = "REGISTRATION_RESPONSE"
    case sessionEnd = "SESSION_END"
    case deleteAccount = "DELETE_ACCOUNT"
    case backupCompleted = "BACKUP_COMPLETED"
    case keynReset = "KEYN_RESET"
    case passwordCopy = "PASSWORD_COPY"
    case requestDenied = "REQUEST_DENIED"
    case siteReported = "SITE_REPORTED"
    case siteAdded = "SITE_ADDED"
    case accountsRestored = "ACCOUNTS_RESTORED"
    case userFeedback = "USER_FEEDBACK"
    case accountMigration = "ACCOUNT_MIGRATION"
}

// Used by Session
struct PairingResponse: Codable {
    let sessionID: String
    let pubKey: String
    let sns: String
    let userID: String
}

struct BrowserMessage: Codable {
    let s: String?          // PPDHandle
    let r: BrowserMessageType
    let b: Int?          // browserTab
    let n: String?       // Site name
    let v: Bool?         // Value for change password confirmation
    let p: String?       // Old password
    let u: String?       // Possible username
    let a: String?       // AccountID
}

struct CredentialsResponse: Codable {
    let u: String?       // Username
    let p: String?      // Password
    let np: String?     // New password (for reset only! When registering p will be set)
    let b: Int
    let a: String?      // AccountID. Only used with changePasswordRequests
    let o: String?      // OTP code
}

struct PushNotification {
    let sessionID : String
    let siteID: String
    let siteName: String
    let browserTab: Int
    let currentPassword: String?
    let requestType: BrowserMessageType
    let username: String?
}

enum BrowserMessageType: Int, Codable {
    case pair
    case login
    case register
    case change
    case reset
    case add
    case addAndChange
    case end
    case acknowledge
    case fill
}

enum KeyType: UInt64 {
    case passwordSeed, backupSeed
}
