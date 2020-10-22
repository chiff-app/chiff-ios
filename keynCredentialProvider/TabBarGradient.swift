//
//  TabBarGradient.swift
//  keynCredentialProvider
//
//  Created by Bas Doorn on 12/06/2019.
//  Copyright © 2019 keyn. All rights reserved.
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
