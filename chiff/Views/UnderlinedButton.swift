//
//  LocalizableButton.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import UIKit
import ChiffCore

@IBDesignable class UnderlinedButton: UIButton, XIBLocalizable {

    @IBInspectable var localizationKey: String? {
        didSet {
            if let key = localizationKey {
                UIView.performWithoutAnimation {
                    let attributedTitle = key.attributedLocalized(color: self.titleLabel?.textColor ?? UIColor.textColor,
                                                                  font: self.titleLabel?.font ?? UIFont.primaryMediumSmall,
                                                                  attributes: [NSAttributedString.Key.underlineStyle: 1])
                    self.setAttributedTitle(attributedTitle, for: .normal)
                    layoutIfNeeded()
                }

            }
        }
    }

}
