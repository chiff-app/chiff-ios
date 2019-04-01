
//
//  AccountTableViewCell.swift
//  keyn
//
//  Created by Bas Doorn on 22/03/2019.
//  Copyright © 2019 keyn. All rights reserved.
//

import UIKit

class SelfSizingTableView: UITableView {
    override var contentSize:CGSize {
        didSet {
            invalidateIntrinsicContentSize()
        }
    }

    override var intrinsicContentSize: CGSize {
        layoutIfNeeded()
        return CGSize(width: UIView.noIntrinsicMetric, height: contentSize.height)
    }

    override func awakeFromNib() {
        layer.borderColor = UIColor.primaryTransparant.cgColor
        layer.borderWidth = 1.0
        layer.cornerRadius = 6.0

        separatorColor = UIColor.primaryTransparant
        separatorStyle = .singleLine
    }
}
