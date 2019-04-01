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
        mGradient.frame = self.bounds
        var colors = [CGColor]()
        colors.append(UIColor(red: 242 / 255, green: 240 / 255, blue: 250 / 255, alpha: 0).cgColor)
        colors.append(UIColor(red: 242 / 255, green: 240 / 255, blue: 250 / 255, alpha: 1).cgColor)

        mGradient.colors = colors
        layer.addSublayer(mGradient)
    }

}
