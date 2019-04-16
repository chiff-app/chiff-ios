//
//  SiteTableViewCell.swift
//  keyn
//
//  Created by Bas Doorn on 16/04/2019.
//  Copyright © 2019 keyn. All rights reserved.
//

import UIKit

class SiteTableViewCell: UITableViewCell {
    @IBOutlet weak var websiteURLTextField: UITextField!

    var oldValue: String?
    var isChanged: Bool = false
    var index: Int!

    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        if editing {
            oldValue = websiteURLTextField.text
        } else {
            if oldValue != websiteURLTextField.text {
                isChanged = true
            }
            oldValue = nil
        }
        websiteURLTextField.isEnabled = editing
    }

}
