//
//  ErrorViewController.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import UIKit

class ErrorViewController: UIViewController {

    @IBOutlet weak var errorTitleLabel: UILabel!
    @IBOutlet weak var errorMessageLabel: UILabel!

    var errorTitle: String!
    var errorMessage: String!

    override func viewDidLoad() {
        super.viewDidLoad()
        errorTitleLabel.text = "errors.generic_problem".localized
        errorMessageLabel.text = errorMessage
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

}
