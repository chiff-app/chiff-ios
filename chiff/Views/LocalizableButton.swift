//
//  LocalizableButton.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import UIKit
import ChiffCore

@IBDesignable class LocalizableButton: UIButton, XIBLocalizable {

    @IBInspectable var localizationKey: String? {
        didSet {
            UIView.performWithoutAnimation {
                setTitle(localizationKey?.localized, for: .normal)
                layoutIfNeeded()
            }
        }
    }

}
