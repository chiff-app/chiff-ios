//
//  LocalizableTextField.swift
//  keyn
//
//  Created by Bas Doorn on 23/08/2019.
//  Copyright © 2019 keyn. All rights reserved.
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
