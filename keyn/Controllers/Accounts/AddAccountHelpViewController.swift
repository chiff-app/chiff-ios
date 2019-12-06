//
//  AddAccountHelpViewController.swift
//  keyn
//
//  Created by Bas Doorn on 26/04/2019.
//  Copyright © 2019 keyn. All rights reserved.
//

import UIKit

class AddAccountHelpViewController: UIViewController {

    @IBOutlet weak var howToAddAnAccountButton: KeynButton!

    @IBAction func howToAddAnAccount(_ sender: Any) {
        self.performSegue(withIdentifier: Properties.deniedPushNotifications ? "AddAccount" : "AddAccountHelp", sender: self)
    }

}
