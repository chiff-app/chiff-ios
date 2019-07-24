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

    override var isSelected: Bool {
        didSet {
            layer.borderColor = isSelected ? UIColor.primary.cgColor : UIColor.primaryTransparant.cgColor
        }
    }

    override func awakeFromNib() {
        layer.borderColor = UIColor.primaryTransparant.cgColor
        layer.borderWidth = 2.0
        layer.cornerRadius = 6.0
    }

}
