//
//  KeynBarButton.swift
//  keyn
//
//  Created by Bas Doorn on 02/04/2019.
//  Copyright © 2019 keyn. All rights reserved.
//

import UIKit

class KeynBarButton: UIButton {

    static let offset: CGFloat = 3

    var barButtonItem: UIBarButtonItem {
        self.transform = CGAffineTransform(translationX: 0, y: KeynBarButton.offset)
        let buttonContainer = UIView(frame: self.frame)
        buttonContainer.addSubview(self)
        return UIBarButtonItem(customView: buttonContainer)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.imageView?.clipsToBounds = false
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}
