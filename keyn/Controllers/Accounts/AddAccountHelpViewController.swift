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

    override func viewDidLoad() {
        super.viewDidLoad()

        NotificationCenter.default.addObserver(forName: .notificationSettingsUpdated, object: nil, queue: OperationQueue.main) { (notification) in
            DispatchQueue.main.async {
                self.howToAddAnAccountButton.setTitle(Properties.deniedPushNotifications ? "Add an account" : "How to add an account", for: .normal)
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        howToAddAnAccountButton.setTitle(Properties.deniedPushNotifications ? "Add an account" : "How to add an account", for: .normal)
    }

    @IBAction func howToAddAnAccount(_ sender: Any) {
        self.performSegue(withIdentifier: Properties.deniedPushNotifications ? "AddAccount" : "AddAccountHelp", sender: self)
    }

}
