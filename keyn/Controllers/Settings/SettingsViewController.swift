/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit
import JustLog

class SettingsViewController: UITableViewController {
    @IBOutlet weak var newSiteNotficationSwitch: UISwitch!

    var securityFooterText = "\u{26A0} Paper backup not finished."
    var justLoaded = true
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setFooterText()
        newSiteNotficationSwitch.isOn = AWS.shared.isSubscribed()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !justLoaded {
            setFooterText()
        } else { justLoaded = false }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if section == 0 {
            return securityFooterText
        }
        if section == 2 {
            return "Resetting Keyn will delete the seed and all accounts."
        }
        if section == 1 {
            return "Use this form to provide feedback :)"
        }
        return nil
    }

    // MARK: - Actions

    @IBAction func newSiteNotificationSwitch(_ sender: UISwitch) {
        if sender.isOn {
            AWS.shared.subscribe()
        } else {
            AWS.shared.unsubscribe()
        }
    }
    
    @IBAction func resetKeyn(_ sender: UIButton) {
        let alert = UIAlertController(title: "Reset Keyn?", message: "This will delete the seed and all passwords.", preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Reset", style: .destructive, handler: { action in
            Session.deleteAll()
            Account.deleteAll()
            try? Seed.delete()
            BackupManager.shared.deleteAllKeys()
            AWS.shared.deleteEndpointArn()
            Logger.shared.info("Keyn reset.", userInfo: ["code": AnalyticsMessage.keynReset.rawValue])
            UIApplication.shared.registerForRemoteNotifications()
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
    
    // MARK: - Private

    private func setFooterText() {
        tableView.reloadSections(IndexSet(integer: 0), with: .none)
        do {
            securityFooterText = try Seed.isBackedUp() ? "The paper backup is the only way to recover your accounts if your phone gets lost or broken." : "\u{26A0} Paper backup not finished."
        } catch {
            Logger.shared.warning("Could determine if seed is backed up.", error: error as NSError)
        }
    }
}
