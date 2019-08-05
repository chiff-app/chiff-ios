/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit

class PrivacyViewController: UITableViewController {

    @IBOutlet weak var shareErrorSwitch: UISwitch!
    @IBOutlet weak var shareAnalyticsSwitch: UISwitch!

    var footerText: String {
        return Properties.environment == .beta ? "settings.privacy_beta_explanation".localized : "settings.privacy_explanation".localized
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.layer.borderColor = UIColor.primaryTransparant.cgColor
        tableView.layer.borderWidth = 1.0
        tableView.separatorColor = UIColor.primaryTransparant
        shareErrorSwitch.isOn = Properties.errorLogging
        shareAnalyticsSwitch.isOn = Properties.analyticsLogging
        if Properties.environment == .beta {
            shareErrorSwitch.isEnabled = false
            shareAnalyticsSwitch.isEnabled = false
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        (tabBarController as! RootViewController).showGradient(true)
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return section == 0 ? "settings.privacy".localized : nil
    }

    // This gets overrided by willDisplayFooterView, but this sets the correct height
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch section {
            case 0: return footerText
            case 1: return "settings.reset_warning".localized
            case 2: return "settings.delete_warning".localized
            default: fatalError("Too many sections")
        }
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
        switch section {
            case 0: footer.textLabel?.text = footerText
            case 1: footer.textLabel?.text = "settings.reset_warning".localized
            case 2: footer.textLabel?.text = "settings.delete_warning".localized
            default: fatalError("Too many sections")
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
            Logger.shared.analytics(.resetKeyn)
            let storyboard: UIStoryboard = UIStoryboard.get(.initialisation)
            UIApplication.shared.keyWindow?.rootViewController = storyboard.instantiateViewController(withIdentifier: "InitialisationViewController")
        }))
        self.present(alert, animated: true, completion: nil)
    }

    @IBAction func deleteData(_ sender: UIButton) {
        let alert = UIAlertController(title: "popups.questions.delete_data".localized, message: "settings.delete_data_warning".localized, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "popups.responses.cancel".localized, style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "popups.responses.delete".localized, style: .destructive, handler: { action in
            BackupManager.shared.deleteAllAccounts() { error in
                DispatchQueue.main.async {
                    if let error = error {
                        self.showError(message: "\("errors.deleting".localized): \(error)")
                    } else {
                        self.deleteLocalData()
                    }
                }
            }
            Logger.shared.analytics(.deleteData)
            let storyboard: UIStoryboard = UIStoryboard.get(.initialisation)
            UIApplication.shared.keyWindow?.rootViewController = storyboard.instantiateViewController(withIdentifier: "InitialisationViewController")
        }))
        self.present(alert, animated: true, completion: nil)
    }

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let destination = segue.destination.contents as? WebViewController {
            let urlPath = Bundle.main.path(forResource: "privacy_policy", ofType: "html")
            destination.url = URL(fileURLWithPath: urlPath!)
        }
    }

    // MARK: - Private functions

    private func deleteLocalData() {
        Session.deleteAll()
        Account.deleteAll()
        try? Seed.delete()
        NotificationManager.shared.deleteEndpoint()
        BackupManager.shared.deleteAllKeys()
        Properties.purgePreferences()
    }

}
