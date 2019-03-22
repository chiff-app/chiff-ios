//
//  KeynButton.swift
//  keyn
//
//  Created by Bas Doorn on 20/03/2019.
//  Copyright © 2019 keyn. All rights reserved.
//

import UIKit


enum KeynButtonType: String {
    case primary
    case secondary
    case tertiary
    case accent
}

@IBDesignable class KeynButton: UIButton {

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
            switch type {
            case .primary:
                backgroundColor = UIColor.primary
                tintColor = UIColor.white
            case .secondary:
                backgroundColor = UIColor.primaryLight
                tintColor = UIColor.primary
            case .tertiary:
                backgroundColor = UIColor.white
                layer.borderColor = UIColor.primaryLight.cgColor
                layer.borderWidth = 1.0
            case .accent:
                backgroundColor = UIColor.secondary
                tintColor = UIColor.white
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
