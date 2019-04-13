//
//  TabBarGradient.swift
//  keyn
//
//  Created by Bas Doorn on 01/04/2019.
//  Copyright © 2019 keyn. All rights reserved.
//

import UIKit

class TabBarGradient: UIView {

    override func layoutSubviews() {
        super.layoutSubviews()
        let mGradient = CAGradientLayer()
        mGradient.frame = CGRect(x: self.bounds.minX, y: self.bounds.minY - 60.0, width: self.bounds.width, height: 150.0)
        var colors = [CGColor]()
        colors.append(UIColor.primaryVeryLight.withAlphaComponent(0).cgColor)
        colors.append(UIColor.primaryVeryLight.withAlphaComponent(1).cgColor)
        mGradient.locations = [NSNumber(value: 0.0),NSNumber(value: 0.6)]
        mGradient.colors = colors
        layer.addSublayer(mGradient)
    }

}
