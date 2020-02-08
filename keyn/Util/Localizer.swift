/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit

protocol Localizable {
    var localized: String { get }
    func attributedLocalized(color: UIColor) -> NSAttributedString
}

protocol XIBLocalizable {
    var localizationKey: String? { get set }
}

private class Localizer {
    
    static let shared = Localizer()
    
    lazy var localizableDictionary: NSDictionary! = {
        #if !TARGET_INTERFACE_BUILDER
        let bundle = Bundle.main
        #else
        let bundle = Bundle(for: type(of: self))
        #endif
        if let path = bundle.path(forResource: "Localized", ofType: "plist") {
            return NSDictionary(contentsOfFile: path)
        }
        fatalError("Localizable file not found.")
    }()
    
    func localize(string: String) -> String {
        let localizableGroup = localizedGroup(string: string)

        // When the localizable is a Dictionary with at least a 'value' item
        guard let localizedString = localizableGroup["value"] as? String else {
            Logger.shared.error("Missing translation for: \(string)")
            return "(Translation missing)"
        }
        return localizedString
    }

    func localize(string: String, accentColor: UIColor, font: UIFont?, attributes: [NSAttributedString.Key: Any]) -> NSMutableAttributedString {
        let localizableGroup = localizedGroup(string: string)

        // When the localizable is a Dictionary with at least a 'value' item
        guard let localizedString = localizableGroup["value"] as? String else {
            assertionFailure("Missing translation for: \(string)")
            return NSMutableAttributedString(string: "")
        }
        let attributedString = NSMutableAttributedString(string: localizedString, attributes: attributes)
        if let start = localizableGroup["start"] as? Int {
            let end = localizableGroup["end"] as? Int
            var attributes: [NSAttributedString.Key: Any] = [NSAttributedString.Key.foregroundColor: accentColor]
            if let font = font {
                attributes[NSAttributedString.Key.font] = font as Any
            }
            attributedString.setAttributes(attributes, range: NSRange(start..<(end ?? localizedString.count)))
        }
        return attributedString
    }

    func localizedGroup(string: String) -> NSDictionary {
        var localizableGroup = localizableDictionary!
        let components = string.components(separatedBy: ".")

        for component in components {
            guard let localizedValue = localizableGroup[component] as? NSDictionary else {
                Logger.shared.error("Missing translation for: \(string)")
                return NSDictionary()
            }
            localizableGroup = localizedValue
        }

        return localizableGroup
    }

}

extension String {

    var localized: String {
        return Localizer.shared.localize(string: self)
    }

    func attributedLocalized(color: UIColor, font: UIFont?, attributes: [NSAttributedString.Key: Any]) -> NSMutableAttributedString {
        return Localizer.shared.localize(string: self, accentColor: color, font: font, attributes: attributes)
    }
}
