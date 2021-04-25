//
//  KeynLabel.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import UIKit
import ChiffCore

@IBDesignable class KeynLabel: UILabel, XIBLocalizable {

    @IBInspectable var isAttributed: Bool = true {
        didSet {
            decorate()
        }
    }

    @IBInspectable var localizationKey: String? {
        didSet {
            decorate()
        }
    }

    @IBInspectable var lineHeight: CGFloat = 26 {
        didSet {
            decorate()
        }
    }

    @IBInspectable var accentColor: UIColor = UIColor.secondary {
        didSet {
            decorate()
        }
    }

    @IBInspectable var accentIsBold: Bool = false {
        didSet {
            decorate()
        }
    }

    override func prepareForInterfaceBuilder() {
        decorate()
        super.prepareForInterfaceBuilder()
    }

    func decorate() {
        guard let key = localizationKey else {
            return
        }
        guard isAttributed else {
            self.attributedText = nil
            self.text = key.localized
            return
        }
        let style = NSMutableParagraphStyle()
        style.alignment = self.textAlignment
        style.minimumLineHeight = lineHeight
        style.maximumLineHeight = lineHeight
        let font = self.font ?? UIFont.primaryMediumNormal
        self.attributedText = key.attributedLocalized(color: accentColor, font: accentIsBold ? UIFont.primaryBoldWith(size: font!.pointSize) : nil, attributes: [
            NSAttributedString.Key.foregroundColor: self.textColor ?? UIColor.textColor,
            NSAttributedString.Key.font: font as Any,
            NSAttributedString.Key.paragraphStyle: style
        ])
        lineBreakMode = .byTruncatingTail
    }

}
