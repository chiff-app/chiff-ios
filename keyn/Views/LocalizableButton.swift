//
//  LocalizableButton.swift
//  keyn
//
//  Created by Bas Doorn on 23/08/2019.
//  Copyright © 2019 keyn. All rights reserved.
//

import UIKit

@IBDesignable class LocalizableButton: UIButton, XIBLocalizable {

    @IBInspectable var localizationKey: String? = nil {
        didSet {
            if let key = localizationKey {
                let attributedTitle = key.attributedLocalized(color: self.titleLabel?.textColor ?? UIColor.textColor,
                                                              font: self.titleLabel?.font ?? UIFont.primaryMediumSmall,
                                                              attributes: [NSAttributedString.Key.underlineStyle : 1])
                self.setAttributedTitle(attributedTitle, for: .normal)
            }
        }
    }


}
