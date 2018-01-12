//
//  PersonalDetailTableViewCell.swift
//  keyn
//
//  Created by bas on 07/01/2018.
//  Copyright © 2018 keyn. All rights reserved.
//

import UIKit

class PersonalDetailTableViewCell: UITableViewCell {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var valueTextField: UITextField!

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
