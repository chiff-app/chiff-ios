/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit

class ErrorViewController: UIViewController {

    @IBOutlet weak var errorTitleLabel: UILabel!
    @IBOutlet weak var errorMessageLabel: UILabel!

    var errorTitle: String!
    var errorMessage: String!

    override func viewDidLoad() {
        super.viewDidLoad()
        errorTitleLabel.text = "generic_problem".localized
        errorMessageLabel.text = errorMessage
    }

}
