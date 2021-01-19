//
//  TabBarGradient.swift
//  chiffCredentialProvider
//
//  Copyright: see LICENSE.md
//

import UIKit

class TabBarGradient: UIView {

    override func layoutSubviews() {
        super.layoutSubviews()
        addBackgroundLayer()
    }

    private func addBackgroundLayer() {
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = bounds
        var colors = [CGColor]()
        colors.append(UIColor.primaryVeryLight.withAlphaComponent(0).cgColor)
        colors.append(UIColor.primaryVeryLight.withAlphaComponent(1).cgColor)
        gradientLayer.locations = [NSNumber(value: 0.0), NSNumber(value: 1.0)]
        gradientLayer.colors = colors
        layer.insertSublayer(gradientLayer, at: 0)
    }

}
