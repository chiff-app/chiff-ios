//
//  SettingsViewController.swift
//  keyn
//
//  Created by bas on 02/01/2018.
//  Copyright © 2018 keyn. All rights reserved.
//

import UIKit

class SettingsViewController: UITableViewController {

    var securityFooterText = "\u{26A0} Paper backup not finished."

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        do {
            securityFooterText = try Seed.isBackedUp() ? "The paper backup is the only way to recover your accounts if your phone gets lost or broken." : "\u{26A0} Paper backup not finished."
            tableView.reloadSections(IndexSet(integer: 0), with: .none)
        } catch {
            print("TODO: Handle error")
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if section == 0 {
            return securityFooterText
        }
        if section == 1 {
            return "Resetting Keyn will delete the seed and all accounts."
        }
        return nil
    }

    // MARK: Actions

    @IBAction func resetKeyn(_ sender: UIButton) {
        let alert = UIAlertController(title: "Reset Keyn?", message: "This will delete the seed and all passwords.", preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Reset", style: .destructive, handler: { action in
            Session.deleteAll()
            Account.deleteAll()
            try? Seed.delete()
            let storyboard: UIStoryboard = UIStoryboard(name: "Initialisation", bundle: nil)
            UIApplication.shared.keyWindow?.rootViewController = storyboard.instantiateViewController(withIdentifier: "InitialisationViewController")
        }))
        self.present(alert, animated: true, completion: nil)
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
