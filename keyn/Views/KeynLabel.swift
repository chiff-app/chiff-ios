//
//  KeynLabel.swift
//  keyn
//
//  Created by Bas Doorn on 22/08/2019.
//  Copyright © 2019 keyn. All rights reserved.
//

import UIKit

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

//    override init(frame: CGRect) {
//        super.init(frame: frame)
//        sharedInit()
//    }
//
//    required init?(coder aDecoder: NSCoder) {
//        super.init(coder: aDecoder)
//        sharedInit()
//    }
//
    override func prepareForInterfaceBuilder() {
        decorate()
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
        self.attributedText = key.attributedLocalized(color: accentColor, font: accentIsBold ? UIFont.primaryBold : nil, attributes: [
            NSAttributedString.Key.foregroundColor: self.textColor ?? UIColor.textColor,
            NSAttributedString.Key.font: self.font ?? UIFont.primaryMediumNormal as Any,
            NSAttributedString.Key.paragraphStyle: style
        ])
        lineBreakMode = .byTruncatingTail
    }

}
