//
//  AccountTableViewCell.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import UIKit
class AccountTableViewCell: UITableViewCell {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var icon: UIImageView!
    @IBOutlet weak var accessoryButton: UIButton!
    @IBOutlet weak var accessoryButtonWidthConstraint: NSLayoutConstraint!

}

class SharedAccountTableViewCell: AccountTableViewCell {

    @IBOutlet weak var teamIcon: UIImageView!
    @IBOutlet weak var teamIconWidthConstraint: NSLayoutConstraint!

}
