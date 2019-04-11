/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit

class SettingsViewController: UITableViewController {

    var securityFooterText = "\u{26A0} \("settings.backup_not_finished".localized)."
    var justLoaded = true
    @IBOutlet weak var paperBackupAlertIcon: UIImageView!

    override func viewDidLoad() {
        super.viewDidLoad()
        setFooterText()
        tableView.layer.borderColor = UIColor.primaryTransparant.cgColor
        tableView.layer.borderWidth = 1.0
        tableView.separatorColor = UIColor.primaryTransparant
        paperBackupAlertIcon.isHidden = Seed.paperBackupCompleted
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !justLoaded {
            setFooterText()
        } else { justLoaded = false }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        setNeedsStatusBarAppearanceUpdate()
    }

    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        guard section == 0 else {
            return
        }

        let header = view as! UITableViewHeaderFooterView
        header.textLabel?.textColor = UIColor.primaryHalfOpacity
        header.textLabel?.font = UIFont.primaryBold
        header.textLabel?.textAlignment = NSTextAlignment.left
        header.textLabel?.frame = header.frame
        header.textLabel?.text = "settings.settings".localized
    }

    override func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
        let footer = view as! UITableViewHeaderFooterView
        footer.textLabel?.textColor = UIColor.textColorHalfOpacity
        footer.textLabel?.font = UIFont.primaryMediumSmall
        footer.textLabel?.textAlignment = NSTextAlignment.left
        footer.textLabel?.frame = footer.frame
        footer.textLabel?.text = section == 0 ? securityFooterText : "settings.reset_warning".localized
        footer.textLabel?.numberOfLines = footer.textLabel!.text!.count > 60 ? 2 : 1
    }

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if indexPath.section == 0 {
            cell.accessoryView = UIImageView(image: UIImage(named: "chevron_right"))
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

    @IBAction func unwindToSettings(sender: UIStoryboardSegue) {
        let completed = Seed.paperBackupCompleted
        paperBackupAlertIcon.isHidden = completed
        if let rootController = tabBarController as? RootViewController {
            rootController.setBadge(completed: completed)
        }
    }
    
    @IBAction func resetKeyn(_ sender: UIButton) {
        let alert = UIAlertController(title: "popups.questions.reset_keyn".localized, message: "popups.questions.reset_keyn_description".localized, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "popups.responses.cancel".localized, style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "popups.responses.reset".localized, style: .destructive, handler: { action in
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

        // MARK: - Private

    private func setFooterText() {
        tableView.reloadSections(IndexSet(integer: 0), with: .none)
        securityFooterText = true ? "settings.backup_completed_footer".localized : "\u{26A0} \("settings.backup_not_finished".localized)."
    }
}
