//
//  KeynTabButton.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import UIKit
import ChiffCore

@IBDesignable class KeynTabButton: UIButton, XIBLocalizable {

    @IBInspectable var localizationKey: String? = nil {
        didSet {
            if let key = localizationKey {
                setTitle(key.localized, for: .normal)
                setTitle(key.localized, for: .selected)
                setTitle(key.localized, for: .highlighted)
            }
        }
    }

    @IBInspectable var keynButtonType: String {
        get {
            return self.type.rawValue
        }
        set(type) {
            self.type = KeynButtonType(rawValue: type) ?? .primary
        }
    }

    var type: KeynButtonType = .primary {
        didSet {
            if type == .primary {
                layer.maskedCorners = [.layerMaxXMinYCorner]
            } else {
                layer.maskedCorners = [.layerMinXMinYCorner]
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        sharedInit()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        sharedInit()
    }

    override func prepareForInterfaceBuilder() {
        sharedInit()
    }

    func sharedInit() {
        layer.cornerRadius = frame.size.height / 2
        titleLabel?.font = UIFont(name: "Montserrat-Bold", size: 14.0)
    }

}
