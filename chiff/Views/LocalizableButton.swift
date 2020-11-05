//
//  LocalizableButton.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import UIKit

@IBDesignable class LocalizableButton: UIButton, XIBLocalizable {

    @IBInspectable var localizationKey: String? = nil {
        didSet {
            UIView.performWithoutAnimation {
                setTitle(localizationKey?.localized, for: .normal)
                layoutIfNeeded()
            }
        }
    }

}
