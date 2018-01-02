//
//  SettingsViewController.swift
//  athena
//
//  Created by bas on 02/01/2018.
//  Copyright © 2018 athena. All rights reserved.
//

import UIKit

class SettingsViewController: UITableViewController {

    @IBOutlet weak var paperBackupWarningLabel: UILabel!

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        do {
            if try !Seed.isBackedUp() {
                paperBackupWarningLabel.isHidden = false
            } else {
                paperBackupWarningLabel.isHidden = true
            }
        } catch {
            print("TODO: Handle error")
        }
    }

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "Backup" {
            if let destination = segue.destination as? BackupStartViewController {
                destination.isInitialSetup = false
            }
        }
    }
}
