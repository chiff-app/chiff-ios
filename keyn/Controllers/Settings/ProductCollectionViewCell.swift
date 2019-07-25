//
//  ProductCollectionViewCell.swift
//  keyn
//
//  Created by Bas Doorn on 24/07/2019.
//  Copyright © 2019 keyn. All rights reserved.
//

import UIKit

class ProductCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var title: UILabel!
    @IBOutlet weak var price: UILabel!
    @IBOutlet weak var savingLabel: RoundLabel!

    var isFirst: Bool = true {
        didSet {
            if isFirst {
                layer.maskedCorners = [.layerMinXMaxYCorner, .layerMinXMinYCorner]
            } else {
                layer.maskedCorners = [.layerMaxXMaxYCorner, .layerMaxXMinYCorner]
            }
        }
    }

    func showSelected() {
        layer.zPosition = isSelected ? 10 : 5
        layer.borderColor = isSelected ? UIColor.primary.cgColor : UIColor.primaryTransparant.cgColor
    }

    override func awakeFromNib() {
        layer.borderColor = UIColor.primaryTransparant.cgColor
        layer.borderWidth = 1.0
        layer.cornerRadius = 6.0
    }

}

class RoundLabel: UILabel {

    override func awakeFromNib() {
        layer.zPosition = CGFloat(INT_MAX)
        layer.cornerRadius = 2.0
    }

}
