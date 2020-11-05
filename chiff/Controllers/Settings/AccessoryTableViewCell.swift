//
//  AccessoryTableViewCell.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import UIKit

class AccessoryTableViewCell: UITableViewCell {

    var enabled: Bool = true {
        didSet {
            label.isEnabled = enabled
            isUserInteractionEnabled = enabled
        }
    }

    @IBOutlet var label: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        accessoryView = UIImageView(image: UIImage(named: "chevron_right"))
    }

}
