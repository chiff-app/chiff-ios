//
//  LocalizableTextField.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import UIKit
import ChiffCore

@IBDesignable class LocalizableTextField: UITextField, XIBLocalizable {

    @IBInspectable var localizationKey: String? = nil {
        didSet {
            if let key = localizationKey {
                placeholder = key.localized
            }
        }
    }
}
