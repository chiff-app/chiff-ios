//
//  LocalizableTextField.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import UIKit

@IBDesignable class LocalizableTextField: UITextField, XIBLocalizable {

    @IBInspectable var localizationKey: String? = nil {
        didSet {
            if let key = localizationKey {
                placeholder = key.localized
            }
        }
    }
}
