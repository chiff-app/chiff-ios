/*
* Copyright © 2019 Keyn B.V.
* All rights reserved.
*/
import UIKit

class KeynTabBar: UITabBar {

    let height: CGFloat = 90
    var gradientView: UIView!

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
            let frame = CGRect(x: self.bounds.minX, y: self.bounds.minY - 60.0, width: self.bounds.width, height: 150.0)
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
        gradientLayer.locations = [NSNumber(value: 0.0),NSNumber(value: 0.6)]
        gradientLayer.colors = colors
        gradientView.layer.insertSublayer(gradientLayer, at: 0)
    }
}
