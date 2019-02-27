/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit

class MPCTableViewCell: UITableViewCell {

    @IBOutlet weak var responseLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        layer.addBorder(edge: .left, color: UIColor(rgb: 0xFFB72F), thickness: 1)
        #warning("TODO: Fix thickness 40 for real.")
        layer.addBorder(edge: .right, color: UIColor(rgb: 0xFFB72F), thickness: 40)
        layer.addBorder(edge: .bottom, color: UIColor(rgb: 0xFFB72F), thickness: 1)
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        if selected {
            backgroundColor = UIColor(rgb: 0xFFB72F)
            responseLabel.textColor = UIColor(rgb: 0x4932A2)
        } else {
            backgroundColor = UIColor(rgb: 0x4932A2)
            responseLabel.textColor = UIColor(rgb: 0xFFB72F)
        }  
    }

}
