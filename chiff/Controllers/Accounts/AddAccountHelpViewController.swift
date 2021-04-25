//
//  AddAccountHelpViewController.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import UIKit
import ChiffCore

class AddAccountHelpViewController: UIViewController {

    @IBOutlet weak var howToAddAnAccountButton: KeynButton!

    @IBAction func howToAddAnAccount(_ sender: Any) {
        self.performSegue(withIdentifier: Properties.deniedPushNotifications ? "AddAccount" : "AddAccountHelp", sender: self)
    }

}
