//
//  KeynBarButton.swift
//  chiff
//
//  Copyright: see LICENSE.md
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
