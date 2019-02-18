/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit

class SettingsViewController: UITableViewController {
    @IBOutlet weak var newSiteNotficationSwitch: UISwitch!

    var securityFooterText = "\u{26A0} \("Settings.backup_not_finished".localized)."
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
        switch section {
        case 0:
            return securityFooterText
        case 1:
            return "feedback_description".localized
        case 2:
            return "reset_warning".localized
        default:
            return nil
        }
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
        let alert = UIAlertController(title: "reset_keyn".localized, message: "reset_keyn_description".localized, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "cancel".localized, style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "reset".localized, style: .destructive, handler: { action in
            Session.deleteAll()
            Account.deleteAll()
            try? Seed.delete()
            BackupManager.shared.deleteAllKeys()
            AWS.shared.deleteEndpointArn()
            Logger.shared.analytics("Keyn reset.", code: .keynReset)
            UIApplication.shared.registerForRemoteNotifications()
            let storyboard: UIStoryboard = UIStoryboard.get(.initialisation)
            UIApplication.shared.keyWindow?.rootViewController = storyboard.instantiateViewController(withIdentifier: "InitialisationViewController")
        }))
        self.present(alert, animated: true, completion: nil)
    }

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "Backup", let destination = segue.destination as? BackupStartViewController {
            destination.isInitialSetup = false
        }
    }
    
    // MARK: - Private

    private func setFooterText() {
        tableView.reloadSections(IndexSet(integer: 0), with: .none)
        do {
            securityFooterText = try Seed.isPaperBackupCompleted() ? "backup_completed_footer".localized : "\u{26A0} \("Settings.backup_not_finished".localized)."
        } catch {
            Logger.shared.warning("Could determine if seed is backed up.", error: error)
        }
    }
}
