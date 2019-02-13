/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import Foundation

private class Localizer {
    
    static let shared = Localizer()
    
    lazy var localizableDictionary: NSDictionary! = {
        if let path = Bundle.main.path(forResource: "Localizable", ofType: "plist") {
            return NSDictionary(contentsOfFile: path)
        }
        
        fatalError("Localizable file NOT found")
    }()
    
    func localize(string: String) -> String {
        var localizableGroup = localizableDictionary!
        let components = string.components(separatedBy: ".")
        
        for component in components {
            guard let localizedValue = localizableGroup[component] as? NSDictionary else {
                if let localizedString = localizableGroup[component] as? String {
                    return localizedString
                }
                assertionFailure("Missing translation for: \(string)")
                return ""
            }
            localizableGroup = localizedValue
        }
        
        // When the localizable is a Dictionary with at least a 'value' item
        guard let localizedString = localizableGroup["value"] as? String else {
            assertionFailure("Missing translation for: \(string)")
            return ""
        }
        
        return localizedString
    }
}

extension String {
    var localized: String {
        return Localizer.shared.localize(string: self)
    }
}
