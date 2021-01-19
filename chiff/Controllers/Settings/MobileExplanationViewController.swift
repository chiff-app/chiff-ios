//
//  MobileExplanationViewController.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import UIKit

class MobileExplanationViewController: UIViewController {

    @IBOutlet weak var firstImage: UIImageView!
    @IBOutlet weak var secondImage: UIImageView!
    @IBOutlet weak var thirdImage: UIImageView!
    @IBOutlet weak var firstLabel: UILabel!
    @IBOutlet weak var secondLabel: UILabel!
    @IBOutlet weak var thirdLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        if #available(iOS 12.0, *) {
            firstImage.image = UIImage(named: "phone_key")
            secondImage.image = UIImage(named: "phone_form")
            thirdImage.image = UIImage(named: "phone_fingerprint")
            firstLabel.text = "settings.mobile_instruction_iOS12.first".localized
            secondLabel.text = "settings.mobile_instruction_iOS12.second".localized
            thirdLabel.text = "settings.mobile_instruction_iOS12.third".localized
        } else {
            firstImage.image = UIImage(named: "phone_form")
            secondImage.image = UIImage(named: "phone_fingerprint")
            thirdImage.image = UIImage(named: "phone_form_filled")
            firstLabel.text = "settings.mobile_instruction_<iOS12.first".localized
            secondLabel.text = "settings.mobile_instruction_<iOS12.second".localized
            thirdLabel.text = "settings.mobile_instruction_<iOS12.third".localized
        }
    }

}
