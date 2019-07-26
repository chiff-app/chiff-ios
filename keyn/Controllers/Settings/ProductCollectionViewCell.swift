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
    @IBOutlet weak var boxView: UIView!
    @IBOutlet weak var radioButton: RadioButton!

    var isFirst: Bool = true {
        didSet {
            if isFirst {
                savingLabel.isHidden = true
                boxView.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMinXMinYCorner]
            } else {
                savingLabel.isHidden = false
                boxView.layer.maskedCorners = [.layerMaxXMaxYCorner, .layerMaxXMinYCorner]
            }
        }
    }

    func showSelected() {
        layer.zPosition = isSelected ? 10 : 5
        boxView.layer.borderColor = isSelected ? UIColor.primary.cgColor : UIColor.primaryTransparant.cgColor
        radioButton.enabled = isSelected
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        boxView.layer.borderColor = UIColor.primaryTransparant.cgColor
        boxView.layer.borderWidth = 1.0
        boxView.layer.cornerRadius = 6.0
        savingLabel.isHidden = isFirst
    }

}

class RoundLabel: UILabel {

    override func awakeFromNib() {
        layer.masksToBounds = true
        layer.zPosition = 15
        layer.cornerRadius = 2.0
    }

}
