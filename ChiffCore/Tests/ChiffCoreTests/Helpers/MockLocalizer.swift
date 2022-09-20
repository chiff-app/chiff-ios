//
//  File.swift
//  
//
//  Created by Bas Doorn on 24/03/2021.
//

#if canImport(UIKit)
import UIKit
#else
import Cocoa
#endif
@testable import ChiffCore

class MockLocalizer: LocalizerProtocol {
    func localize(string: String) -> String {
        return "We're testing!"
    }

    #if canImport(UIKit)
    func localize(string: String, accentColor: UIColor, font: UIFont?, attributes: [NSAttributedString.Key: Any]) -> NSMutableAttributedString {
        return NSMutableAttributedString(string: "We're testing!", attributes: attributes)
    }
    #else
    func localize(string: String, accentColor: NSColor, font: NSFont?, attributes: [NSAttributedString.Key: Any]) -> NSMutableAttributedString {
        return NSMutableAttributedString(string: "We're testing!", attributes: attributes)
    }
    #endif

}
