//
//  AccessoryTableViewCell.swift
//  keyn
//
//  Created by Bas Doorn on 05/08/2019.
//  Copyright © 2019 keyn. All rights reserved.
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
