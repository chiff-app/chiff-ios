/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit
import Sodium
import UserNotifications

// MARK: - Primitive extensions

extension Int {
    func mod(_ n: Int) -> Int {
        return (self % n + n) % n
    }
}

extension String {
    
    var hash: String {
        return try! Crypto.shared.hash(self)
    }
    
    var sha1: String {
        return Crypto.shared.sha1(from: self)
    }
    
    var sha256: String {
        return Crypto.shared.sha256(from: self)
    }
    
    var fromBase64: Data? {
        return try? Crypto.shared.convertFromBase64(from: self)
    }

    func components(withLength length: Int) -> [String] {
        return stride(from: 0, to: self.count, by: length).map {
            let start = self.index(self.startIndex, offsetBy: $0)
            let end = self.index(start, offsetBy: length, limitedBy: self.endIndex) ?? self.endIndex
            return String(self[start..<end])
        }
    }


    // TODO: Make functional
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

extension Substring {
    func pad(toSize: Int) -> String {
        var padded = String(self)
        for _ in 0..<(toSize - self.count) {
            padded = "0" + padded
        }
        return padded
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

extension Data {
    struct HexEncodingOptions: OptionSet {
        let rawValue: Int
        static let upperCase = HexEncodingOptions(rawValue: 1 << 0)
    }
    
    func hexEncodedString(options: HexEncodingOptions = []) -> String {
        let format = options.contains(.upperCase) ? "%02hhX" : "%02hhx"
        return map { String(format: format, $0) }.joined()
    }
    
    var bitstring: String {
        return self.reduce("", { $0 + String($1, radix: 2).pad(toSize: 8) })
    }
    
    var hash: Data {
        return try! Crypto.shared.hash(self)
    }

    var sha256: Data {
        return Crypto.shared.sha256(from: self)
    }

    var base64: String {
        return try! Crypto.shared.convertToBase64(from: self)
    }

    var bytes: Bytes { return Bytes(self) }
}

extension Array where Element == UInt8 {
    public var data: Data {
        return Data(bytes: self)
    }
}

extension Date {
    func timeAgoSinceNow(useNumericDates: Bool = false) -> String {
        let calendar = Calendar.current
        let unitFlags: Set<Calendar.Component> = [.minute, .hour, .day, .weekOfYear, .month, .year, .second]
        let now = Date()
        let components = calendar.dateComponents(unitFlags, from: self, to: now)
        let formatter = DateComponentUnitFormatter()
        return formatter.string(forDateComponents: components, useNumericDates: useNumericDates)
    }
}

extension TimeInterval {
    static let ONE_DAY: TimeInterval = 3600*24
}


// MARK: - Notifications

extension Notification.Name {
    static let passwordChangeConfirmation = Notification.Name("PasswordChangeConfirmation")
    static let sessionStarted = Notification.Name("SessionStarted")
    static let sessionEnded = Notification.Name("SessionEnded")
    static let accountAdded = Notification.Name("AccountAdded")
    static let accountsLoaded = Notification.Name("AccountsLoaded")
}

// MARK: - UIExtensions

// Extension for UIViewController that return visible view controller if it is a navigationController
extension UIViewController {
    var contents: UIViewController {
        if let navigationController = self as? UINavigationController {
            return navigationController.visibleViewController ?? self
        } else {
            return self
        }
    }

    @IBAction func dismiss(sender: UIStoryboardSegue) {
        doDismiss(animated: false)
    }

    @IBAction func dismissAnimated(sender: UIStoryboardSegue) {
        doDismiss(animated: true)
    }

    @IBAction func dismissModallyAnimated(sender: UIStoryboardSegue) {
        dismiss(animated: true, completion: nil)
    }

    private func doDismiss(animated: Bool) {
        if let navCon = navigationController {
            navCon.popViewController(animated: animated)
        } else {
            dismiss(animated: animated, completion: nil)
        }
    }

}

extension UIStoryboard {
    
    enum StoryboardType: String {
        case main = "Main"
        case initialisation = "Initialisation"
        case request = "Request"
        case launchScreen = "LaunchScreen"
        case feedback = "Feedback"
    }
    
    static var main: UIStoryboard {
        return get(.main)
    }
    
    static func get(_ type: StoryboardType) -> UIStoryboard {
        return UIStoryboard(name: type.rawValue, bundle: nil)
    }
    
}

struct System {

    static func clearNavigationBar(forBar navBar: UINavigationBar) {
        navBar.setBackgroundImage(UIImage(), for: .default)
        navBar.shadowImage = UIImage()
        navBar.isTranslucent = true
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

    static var primary: UIColor = {
        return UIColor(rgb: 0x4722C3)
    }()
    static var primaryHalfOpacity: UIColor = {
        return UIColor(rgb: 0x9B88DD)
    }()
    static var primaryTransparant: UIColor = {
        return UIColor(rgb: 0xC7BCEE)
    }()
    static var primaryDark: UIColor = {
        return UIColor(rgb: 0x120050)
    }()
    static var primaryLight: UIColor = {
        return UIColor(rgb: 0xE5E1F5)
    }()
    static var primaryVeryLight: UIColor = {
        return UIColor(rgb: 0xF2F0FA)
    }()
    static var textColor: UIColor = {
        return UIColor(rgb: 0x4C5698)
    }()
    static var textColorHalfOpacity: UIColor = {
        return UIColor(rgb: 0x9FA3C9)
    }()
    static var secondary: UIColor = {
        return UIColor(rgb: 0xEE8C00)
    }()
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

extension UITableViewCell {
    static let defaultHeight: CGFloat = 44
}

extension UNNotificationContent {
    func isProcessed() -> Bool {
        return self.userInfo[NotificationContentKey.type] != nil
    }
}

extension UINavigationController {
    open override var childForStatusBarStyle: UIViewController? {
        return visibleViewController
    }
}
