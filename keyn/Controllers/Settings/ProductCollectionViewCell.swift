//
//  ProductCollectionViewCell.swift
//  keyn
//
//  Created by Bas Doorn on 24/07/2019.
//  Copyright © 2019 keyn. All rights reserved.
//

import UIKit

enum ProductCellType {
    case discount
    case active
    case none
}

class ProductCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var title: UILabel!
    @IBOutlet weak var price: UILabel!
    @IBOutlet weak var savingLabel: RoundLabel!
    @IBOutlet weak var boxView: UIView!
    @IBOutlet weak var radioButton: RadioButton!

    var isFirst: Bool = true {
        didSet {
            if isFirst {
                boxView.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMinXMinYCorner]
            } else {
                boxView.layer.maskedCorners = [.layerMaxXMaxYCorner, .layerMaxXMinYCorner]
            }
        }
    }

    var type: ProductCellType = .none {
        didSet {
            switch type {
            case .discount:
                savingLabel.isHidden = false
                savingLabel.backgroundColor = UIColor.primary
                savingLabel.text = "settings.discount".localized
            case .active:
                savingLabel.isHidden = false
                savingLabel.backgroundColor = UIColor.keynGreen
                savingLabel.text = "settings.active".localized
            case .none:
                savingLabel.isHidden = true
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
    }

}

@IBDesignable class RoundLabel: UILabel {

    @IBInspectable var topInset: CGFloat = 5.0
    @IBInspectable var bottomInset: CGFloat = 5.0
    @IBInspectable var leftInset: CGFloat = 7.0
    @IBInspectable var rightInset: CGFloat = 7.0

    override func awakeFromNib() {
        super.awakeFromNib()
        layer.masksToBounds = true
        layer.zPosition = 15
        layer.cornerRadius = 2.0
    }

    override func drawText(in rect: CGRect) {
        let insets = UIEdgeInsets(top: topInset, left: leftInset, bottom: bottomInset, right: rightInset)
        super.drawText(in: rect.inset(by: insets))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + leftInset + rightInset,
                      height: size.height + topInset + bottomInset)
    }

}
