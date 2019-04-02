//
//  KeynBarButton.swift
//  keyn
//
//  Created by Bas Doorn on 02/04/2019.
//  Copyright © 2019 keyn. All rights reserved.
//

import UIKit

class KeynBarButton: UIButton {

    static let offset: CGFloat = 40

    var barButtonItem: UIBarButtonItem {
        self.transform = CGAffineTransform(translationX: 0, y: KeynBarButton.offset)
        let buttonContainer = UIView(frame: self.frame)
        buttonContainer.addSubview(self)
        return UIBarButtonItem(customView: buttonContainer)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        let lowerPoint = point.applying(CGAffineTransform.identity.translatedBy(x: 0, y: KeynBarButton.offset))
        return super.point(inside: lowerPoint, with: event)
    }

}

extension UINavigationBar {
    override open func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard isUserInteractionEnabled && !isHidden && alpha >= 0.01 else {
            return nil
        }

        guard self.point(inside: point, with: event) else {
            return nil
        }

        for subview in subviews.reversed() {
            let convertedPoint = subview.convert(point, from: self)
            if let candidate = subview.hitTest(convertedPoint, with: event) {
                return candidate
            } else if "\(type(of: subview))" == "_UINavigationBarContentView" {
                let higherPoint = convertedPoint.applying(CGAffineTransform.identity.translatedBy(x: 0, y: -KeynBarButton.offset))
                if let secondCandidate = subview.hitTest(higherPoint, with: event), secondCandidate is KeynBarButton {
                    return secondCandidate
                }
            }
        }
        return self
    }
}
