//
//  LocalizableButton.swift
//  keyn
//
//  Created by Bas Doorn on 26/08/2019.
//  Copyright © 2019 keyn. All rights reserved.
//

import UIKit

@IBDesignable class LocalizableButton: UIButton, XIBLocalizable {

    @IBInspectable var localizationKey: String? = nil {
        didSet {
            if let key = localizationKey {
                setTitle(key.localized, for: .normal)
            }
        }
    }

}
