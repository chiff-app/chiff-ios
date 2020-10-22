/*
* Copyright © 2019 Keyn B.V.
* All rights reserved.
*/
import UIKit

class KeynTabBar: UITabBar {

    let height: CGFloat = 90
    var gradientView: UIView!

    override init(frame: CGRect) {
        super.init(frame: frame)
        sharedInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        sharedInit()
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        guard let window = UIApplication.shared.keyWindow else {
            return super.sizeThatFits(size)
        }
        var sizeThatFits = super.sizeThatFits(size)
        if #available(iOS 11.0, *) {
            sizeThatFits.height = height + window.safeAreaInsets.bottom
        } else {
            sizeThatFits.height = height
        }
        return sizeThatFits
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if gradientView == nil {
            var frame: CGRect
            if #available(iOS 13.0, *) {
                frame = CGRect(x: self.bounds.minX, y: self.bounds.minY, width: self.bounds.width, height: self.bounds.height)
            } else {
                frame = CGRect(x: self.bounds.minX, y: self.bounds.minY - 60.0, width: self.bounds.width, height: 190.0)
            }
            gradientView = UIView(frame: frame)
            addBackgroundLayer()
            self.insertSubview(gradientView, at: 0)
        }
    }

    private func addBackgroundLayer() {
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = gradientView.bounds
        var colors = [CGColor]()
        colors.append(UIColor.primaryVeryLight.withAlphaComponent(0).cgColor)
        colors.append(UIColor.primaryVeryLight.withAlphaComponent(1).cgColor)
        if #available(iOS 13.0, *) {
            gradientLayer.locations = [NSNumber(value: 0.0), NSNumber(value: 0.3)]
        } else {
            gradientLayer.locations = [NSNumber(value: 0.0), NSNumber(value: 0.5)]
        }
        gradientLayer.colors = colors
        gradientView.layer.insertSublayer(gradientLayer, at: 0)
    }

    private func sharedInit() {
        if #available(iOS 13.0, *) {
            layer.borderWidth = 0.50
            layer.borderColor = UIColor.clear.cgColor
            clipsToBounds = true
        }
    }
}
