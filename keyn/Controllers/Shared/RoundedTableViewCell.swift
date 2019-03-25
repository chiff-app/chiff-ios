
//
//  AccountTableViewCell.swift
//  keyn
//
//  Created by Bas Doorn on 22/03/2019.
//  Copyright © 2019 keyn. All rights reserved.
//

import UIKit

enum RoundedTableViewCellType {
    case first
    case last
    case single
    case middle
}

class RoundedTableViewCell: UITableViewCell {

    var type: RoundedTableViewCellType = .single {
        didSet {
            adjustSize()
        }
    }

    var frameHasBeenUpdated = false

    override var frame: CGRect {
        get {
            return super.frame
        }
        set (newFrame) {
            super.frame = calculateFrame(newFrame: newFrame)
            frameHasBeenUpdated = true
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
//        layer.borderColor = UIColor.primaryTransparant.cgColor
//        layer.borderWidth = 1.0
//        layer.addBorder(edge: .bottom, color: UIColor.primaryTransparant, thickness: 1.0)
    }

    private func calculateFrame(newFrame: CGRect) -> CGRect {
        let inset: CGFloat = 20
        var frame = newFrame
        frame.origin.x += inset
        frame.size.width -= 2 * inset
        return frame
    }

    private func adjustSize() {
        switch type {
        case .first:
            layer.cornerRadius = 6
            layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
            contentView.layer.cornerRadius = 6
            contentView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
            contentView.layer.borderColor = UIColor.primaryTransparant.cgColor
            let thickness: CGFloat = 1.0
            contentView.layer.borderWidth = thickness
            let border = CALayer()
            border.backgroundColor = UIColor.white.cgColor
            let width = frameHasBeenUpdated ? frame.width : calculateFrame(newFrame: frame).width
            print(width)
            border.frame = CGRect(x: thickness, y: frame.height - thickness, width: width - ( 2 * thickness), height: thickness)
            layer.addSublayer(border)
        case .last:
            layer.cornerRadius = 6
            layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
            layer.borderColor = UIColor.primaryTransparant.cgColor
            layer.borderWidth = 1.0
            layer.addBorder(edge: .top, color: .white, thickness: 1.0)
        case .single:
            layer.cornerRadius = 6
            layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner, .layerMinXMinYCorner, .layerMaxXMinYCorner]
            layer.borderColor = UIColor.primaryTransparant.cgColor
            layer.borderWidth = 1.0
        case .middle:
            layer.cornerRadius = 0
            layer.maskedCorners = []
            layer.addBorder(edge: .top, color: .primaryTransparant, thickness: 1.0)
            layer.addBorder(edge: .left, color: .primaryTransparant, thickness: 1.0)
            let border = CALayer()
            let width = frameHasBeenUpdated ? frame.width : calculateFrame(newFrame: frame).width
            border.frame = CGRect(x: width - 1.0, y: 0, width: 1.0, height: frame.height)
            border.backgroundColor = UIColor.primaryTransparant.cgColor
            layer.addSublayer(border)
        }
    }

}
