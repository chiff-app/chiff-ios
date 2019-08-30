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

    var buttonLocalizationKey: String {
        return Properties.deniedPushNotifications ? "accounts.add_an_account" : "accounts.how_to_add"
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        NotificationCenter.default.addObserver(forName: .notificationSettingsUpdated, object: nil, queue: OperationQueue.main) { (notification) in
            DispatchQueue.main.async {
                self.howToAddAnAccountButton.localizationKey = self.buttonLocalizationKey
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        howToAddAnAccountButton.localizationKey = buttonLocalizationKey
    }

    @IBAction func howToAddAnAccount(_ sender: Any) {
        self.performSegue(withIdentifier: Properties.deniedPushNotifications ? "AddAccount" : "AddAccountHelp", sender: self)
    }

}
