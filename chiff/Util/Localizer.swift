//
//  Localizer.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import UIKit
import ChiffCore

class ChiffLocalizer: LocalizerProtocol {

    lazy var localizableDictionary: NSDictionary! = {
        let bundle = Bundle.main
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
        if let startString = localizableGroup["start"] as? String,
            let start = Int(startString) {
            var end: Int?
            if let endString = localizableGroup["end"] as? String {
                end = Int(endString)
            }
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
