//
//  DeviceTableViewCell.swift
//  athena
//
//  Created by Bas Doorn on 04/11/2017.
//  Copyright © 2017 athena. All rights reserved.
//

import UIKit

class DeviceTableViewCell: UITableViewCell {
    
    // MARK: Properties

    @IBOutlet weak var deviceName: UILabel!
    @IBOutlet weak var sessionStartTime: UILabel!
    @IBOutlet weak var deleteButton: UIButton!

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
        
    }

}
