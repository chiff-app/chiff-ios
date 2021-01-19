//
//  AccountTableViewCell.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import UIKit

class SelfSizingTableView: UITableView {
    override var contentSize: CGSize {
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
