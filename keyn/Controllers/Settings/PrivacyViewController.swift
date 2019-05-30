/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit

class PrivacyViewController: UITableViewController {

    @IBOutlet weak var shareErrorSwitch: UISwitch!
    @IBOutlet weak var shareAnalyticsSwitch: UISwitch!

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.layer.borderColor = UIColor.primaryTransparant.cgColor
        tableView.layer.borderWidth = 1.0
        tableView.separatorColor = UIColor.primaryTransparant
        shareErrorSwitch.isOn = Properties.errorLogging
        shareAnalyticsSwitch.isOn = Properties.analyticsLogging
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        (tabBarController as! RootViewController).showGradient(false)
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return section == 0 ? "settings.privacy".localized : nil
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return section == 0 ? "settings.privacy_explanation".localized : "settings.reset_warning".localized
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
        header.textLabel?.text = "settings.privacy".localized
    }

    override func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
        let footer = view as! UITableViewHeaderFooterView
        footer.textLabel?.textColor = UIColor.textColorHalfOpacity
        footer.textLabel?.font = UIFont.primaryMediumSmall
        footer.textLabel?.textAlignment = NSTextAlignment.left
        footer.textLabel?.frame = footer.frame
        footer.textLabel?.text = section == 0 ? "settings.privacy_explanation".localized : "settings.reset_warning".localized
    }

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if indexPath.section == 0 && indexPath.row > 1 {
            cell.accessoryView = UIImageView(image: UIImage(named: "chevron_right"))
        }
    }

    // MARK: - Actions

    @IBAction func toggleShareErrors(_ sender: UISwitch) {
        Properties.errorLogging = sender.isOn
    }

    @IBAction func toggleShareAnalytics(_ sender: UISwitch) {
        Properties.analyticsLogging = sender.isOn
    }

    @IBAction func resetKeyn(_ sender: UIButton) {
        let alert = UIAlertController(title: "popups.questions.reset_keyn".localized, message: "settings.reset_keyn_warning".localized, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "popups.responses.cancel".localized, style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "popups.responses.reset".localized, style: .destructive, handler: { action in
            self.deleteLocalData()
            Logger.shared.analytics("Keyn reset.", code: .keynReset)
            let storyboard: UIStoryboard = UIStoryboard.get(.initialisation)
            UIApplication.shared.keyWindow?.rootViewController = storyboard.instantiateViewController(withIdentifier: "InitialisationViewController")
        }))
        self.present(alert, animated: true, completion: nil)
    }

    @IBAction func deleteData(_ sender: UIButton) {
        let alert = UIAlertController(title: "popups.questions.delete_data".localized, message: "settings.delete_data_warning".localized, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "popups.responses.cancel".localized, style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "popups.responses.delete".localized, style: .destructive, handler: { action in
            self.deleteLocalData()
            // TODO: Delete data remotely
            Logger.shared.analytics("Keyn reset.", code: .keynReset)
            let storyboard: UIStoryboard = UIStoryboard.get(.initialisation)
            UIApplication.shared.keyWindow?.rootViewController = storyboard.instantiateViewController(withIdentifier: "InitialisationViewController")
        }))
        self.present(alert, animated: true, completion: nil)
    }

    private func deleteLocalData() {
        Session.deleteAll()
        Account.deleteAll()
        try? Seed.delete()
        NotificationManager.shared.deleteEndpoint()
        BackupManager.shared.deleteAllKeys()
    }

}
