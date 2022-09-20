//
//  Extensions.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import UIKit
import WebKit
import Amplitude
import ChiffCore

extension Amplitude {
    func set(userProperties: [AnalyticsUserProperty: Any]) {
        let properties = Dictionary(uniqueKeysWithValues: userProperties.map({ ($0.key.rawValue, $0.value) }))
        self.setUserProperties(properties)
    }

    func logEvent(event: AnalyticsEvent, properties: [AnalyticsEventProperty: Any]? = nil) {
        if let properties = properties {
            self.logEvent(event.rawValue, withEventProperties: Dictionary(uniqueKeysWithValues: properties.map({ ($0.key.rawValue, $0.value) })))
        } else {
            self.logEvent(event.rawValue)
        }
    }
}

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

    func showAlert(message: String, title: String = "errors.error".localized, handler: ((UIAlertAction) -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: handler))
        self.present(alert, animated: true)
    }

    func reEnableBarButtonFont() {
        if #available(iOS 13.0, *) {
            // Bar button font is disabled for some reason in iOS13..
            navigationItem.leftBarButtonItem?.setTitleTextAttributes([.foregroundColor: UIColor.primary,
                                                           .font: UIFont.primaryBold!], for: UIControl.State.normal)
            navigationItem.leftBarButtonItem?.setTitleTextAttributes([.font: UIFont.primaryBold!], for: UIControl.State.highlighted)
            navigationItem.leftBarButtonItem?.setTitleTextAttributes([.font: UIFont.primaryBold!], for: UIControl.State.selected)
            navigationItem.leftBarButtonItem?.setTitleTextAttributes([.font: UIFont.primaryBold!], for: UIControl.State.focused)
            navigationItem.leftBarButtonItem?.setTitleTextAttributes([.foregroundColor: UIColor.primaryHalfOpacity,
                                                           .font: UIFont.primaryBold!], for: UIControl.State.disabled)
            navigationItem.rightBarButtonItem?.setTitleTextAttributes([.foregroundColor: UIColor.primary,
                                                           .font: UIFont.primaryBold!], for: UIControl.State.normal)
            navigationItem.rightBarButtonItem?.setTitleTextAttributes([.font: UIFont.primaryBold!], for: UIControl.State.highlighted)
            navigationItem.rightBarButtonItem?.setTitleTextAttributes([.font: UIFont.primaryBold!], for: UIControl.State.selected)
            navigationItem.rightBarButtonItem?.setTitleTextAttributes([.font: UIFont.primaryBold!], for: UIControl.State.focused)
            navigationItem.rightBarButtonItem?.setTitleTextAttributes([.foregroundColor: UIColor.primaryHalfOpacity,
                                                           .font: UIFont.primaryBold!], for: UIControl.State.disabled)
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

extension UIView {

    var firstResponder: UIView? {
        guard !isFirstResponder else { return self }

        for subview in subviews {
            if let firstResponder = subview.firstResponder {
                return firstResponder
            }
        }

        return nil
    }

    func addEndEditingTapGesture() {
        self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(UIView.endEditing(_:))))
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
            return navigationController.contents
        }

        if let tabBarController = rootViewController as? UITabBarController {
            return tabBarController.selectedViewController
        }

        return rootViewController
    }

    func showRootController() {
        guard let window = keyWindow else {
            return
        }
        let rootController = UIStoryboard.main.instantiateViewController(withIdentifier: "RootController")
        UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve, animations: {
            DispatchQueue.main.async {
                window.rootViewController = rootController
            }
        })
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

        border.backgroundColor = color.cgColor
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
    static var keynGreen: UIColor = {
        return UIColor(rgb: 0x009C0C)
    }()
}

extension UIFont {
    static var primaryMediumNormal: UIFont? = {
        return UIFont(name: "Montserrat-Medium", size: 14)
    }()

    static var primaryMediumSmall: UIFont? = {
        return UIFont(name: "Montserrat-Medium", size: 12)
    }()

    static var primaryBold: UIFont? = {
        return UIFont(name: "Montserrat-Bold", size: 14)
    }()

    static var primaryBoldSmall: UIFont? = {
        return UIFont(name: "Montserrat-Bold", size: 12)
    }()

    static func primaryBoldWith(size: CGFloat) -> UIFont? {
        return UIFont(name: "Montserrat-Bold", size: size)
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

    func withInsets(_ insets: UIEdgeInsets) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(
            CGSize(width: size.width + insets.left + insets.right,
                   height: size.height + insets.top + insets.bottom),
            false,
            self.scale)

        let origin = CGPoint(x: insets.left, y: insets.top)
        self.draw(at: origin)
        let imageWithInsets = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return imageWithInsets
    }

}

extension UITableViewCell {
    static let defaultHeight: CGFloat = 44
}

extension UNNotificationContent {
    var isProcessed: Bool {
        return self.userInfo[NotificationContentKey.type.rawValue] != nil
    }
}

extension UINavigationController {
    override open var childForStatusBarStyle: UIViewController? {
        return visibleViewController
    }
}

extension UIBarButtonItem {
    func setColor(color: UIColor) {
        setTitleTextAttributes([.foregroundColor: color, .font: UIFont.primaryBold!], for: UIControl.State.normal)
        setTitleTextAttributes([.foregroundColor: color, .font: UIFont.primaryBold!], for: UIControl.State.highlighted)
        setTitleTextAttributes([.foregroundColor: color, .font: UIFont.primaryBold!], for: UIControl.State.selected)
        setTitleTextAttributes([.foregroundColor: color, .font: UIFont.primaryBold!], for: UIControl.State.focused)
        switch color {
        case .white:
            setTitleTextAttributes([.foregroundColor: UIColor.init(white: 1, alpha: 0.5), .font: UIFont.primaryBold!], for: UIControl.State.disabled)
        default:
            setTitleTextAttributes([.foregroundColor: UIColor.primaryHalfOpacity, .font: UIFont.primaryBold!], for: UIControl.State.disabled)
        }
    }
}

// MARK: Printable PDFs

extension WKWebView {

    var pdf: NSData {
        let a4 = CGRect.init(x: 0, y: 0, width: 595.2, height: 841.8)
        let renderer = UIPrintPageRenderer()
        let formatter = viewPrintFormatter()
        formatter.perPageContentInsets = UIEdgeInsets(top: 35.0, left: 25.0, bottom: 35.0, right: 25.0)
        renderer.addPrintFormatter(formatter, startingAtPageAt: 0)
        renderer.setValue(NSValue(cgRect: a4), forKey: "paperRect")
        renderer.setValue(NSValue(cgRect: a4), forKey: "printableRect")
        return renderer.pdf
    }

}

extension UIPrintPageRenderer {

    var pdf: NSData {
        let pdfData = NSMutableData()
        UIGraphicsBeginPDFContextToData(pdfData, self.paperRect, nil)
        self.prepare(forDrawingPages: NSRange(location: 0, length: self.numberOfPages))
        let bounds = UIGraphicsGetPDFContextBounds()
        for page in 0..<self.numberOfPages {
            UIGraphicsBeginPDFPage()
            self.drawPage(at: page, in: bounds)
        }
        UIGraphicsEndPDFContext()
        return pdfData
    }

}
