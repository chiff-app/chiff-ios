
//
//  AccountTableViewCell.swift
//  keyn
//
//  Created by Bas Doorn on 22/03/2019.
//  Copyright © 2019 keyn. All rights reserved.
//

import UIKit

enum AccountTableViewCellType {
    case first
    case last
    case single
    case middle
}

class AccountTableViewCell: UITableViewCell {

    @IBOutlet weak var titleLabel: UILabel!
    var type: AccountTableViewCellType = .single {
        didSet {
            switch type {
            case .first:
                layer.cornerRadius = 6
                layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
            case .last:
                layer.cornerRadius = 6
                layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
            case .single:
                layer.cornerRadius = 6
                layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner, .layerMinXMinYCorner, .layerMaxXMinYCorner]
            case .middle:
                layer.cornerRadius = 0
                layer.maskedCorners = []
            }
        }
    }

    override var frame: CGRect {
        get {
            return super.frame
        }
        set (newFrame) {
            let inset: CGFloat = 20
            var frame = newFrame
            frame.origin.x += inset
            frame.size.width -= 2 * inset
            super.frame = frame
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        layer.borderColor = UIColor.primaryTransparant.cgColor
        layer.borderWidth = 1.0
        
    }

}
