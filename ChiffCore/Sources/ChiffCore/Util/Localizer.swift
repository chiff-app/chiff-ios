//
//  Localizer.swift
//  ChiffCore
//
//  Copyright: see LICENSE.md
//

#if canImport(UIKit)
import UIKit
#else
import Cocoa
#endif

public protocol Localizable {
    var localized: String { get }
    #if canImport(UIKit)
    func attributedLocalized(color: UIColor) -> NSAttributedString
    #else
    func attributedLocalized(color: NSColor) -> NSAttributedString
    #endif
}

public protocol XIBLocalizable {
    var localizationKey: String? { get set }
}

public protocol LocalizerProtocol {
    func localize(string: String) -> String
    #if canImport(UIKit)
    func localize(string: String, accentColor: UIColor, font: UIFont?, attributes: [NSAttributedString.Key: Any]) -> NSMutableAttributedString
    #else
    func localize(string: String, accentColor: NSColor, font: NSFont?, attributes: [NSAttributedString.Key: Any]) -> NSMutableAttributedString
    #endif
}

public class Localizer: LocalizerProtocol {

    public static var shared: LocalizerProtocol = Localizer()

    public func localize(string: String) -> String {
        return string
//        fatalError("Override with custom localizer")
    }

    #if canImport(UIKit)
    public func localize(string: String, accentColor: UIColor, font: UIFont?, attributes: [NSAttributedString.Key: Any]) -> NSMutableAttributedString {
        return NSMutableAttributedString(string: string)
//        fatalError("Override with custom localizer")
    }
    #else
    public func localize(string: String, accentColor: NSColor, font: NSFont?, attributes: [NSAttributedString.Key: Any]) -> NSMutableAttributedString {
        return NSMutableAttributedString(string: string)
//        fatalError("Override with custom localizer")
    }
    #endif
}

extension String {

    /// The localized string for this key. Should be in the format `"group.key"`.
    public var localized: String {
        return Localizer.shared.localize(string: self)
    }

    /// The attributed string for this key, optionally overrding the font. The letters to color should be in the localization file.
    #if canImport(UIKit)
    public func attributedLocalized(color: UIColor, font: UIFont?, attributes: [NSAttributedString.Key: Any]) -> NSMutableAttributedString {
        return Localizer.shared.localize(string: self, accentColor: color, font: font, attributes: attributes)
    }
    #else
    func attributedLocalized(color: NSColor, font: NSFont?, attributes: [NSAttributedString.Key: Any]) -> NSMutableAttributedString {
        return Localizer.shared.localize(string: self, accentColor: color, font: font, attributes: attributes)
    }
    #endif
}
