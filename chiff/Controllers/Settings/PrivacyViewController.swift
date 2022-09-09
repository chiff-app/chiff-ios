//
//  PrivacyViewController.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import UIKit
import PromiseKit
import ChiffCore

class PrivacyViewController: UITableViewController {

    @IBOutlet weak var shareErrorSwitch: UISwitch!
    @IBOutlet weak var shareAnalyticsSwitch: UISwitch!

    var footerText: String {
        return Properties.environment == .staging ? "settings.privacy_beta_explanation".localized : "settings.privacy_explanation".localized
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.layer.borderColor = UIColor.primaryTransparant.cgColor
        tableView.layer.borderWidth = 1.0
        tableView.separatorColor = UIColor.primaryTransparant
        shareErrorSwitch.isOn = Properties.errorLogging
        shareAnalyticsSwitch.isOn = Properties.analyticsLogging
        if Properties.environment == .staging {
            shareErrorSwitch.isEnabled = false
            shareAnalyticsSwitch.isEnabled = false
        }
    }

    // MARK: - UITableView

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

        guard let header = view as? UITableViewHeaderFooterView else {
            Logger.shared.error("Expected UITableViewHeaderFooterView, but found \(type(of: view)).")
            return
        }
        header.textLabel?.textColor = UIColor.primaryHalfOpacity
        header.textLabel?.font = UIFont.primaryBold
        header.textLabel?.textAlignment = NSTextAlignment.left
        header.textLabel?.frame = header.frame
        header.textLabel?.text = "settings.privacy".localized
    }

    override func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
        guard let footer = view as? UITableViewHeaderFooterView else {
            Logger.shared.error("Expected UITableViewHeaderFooterView, but found \(type(of: view)).")
            return
        }
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
        alert.addAction(UIAlertAction(title: "popups.responses.reset".localized, style: .destructive, handler: { _ in
            UIApplication.shared.isNetworkActivityIndicatorVisible = true
            firstly {
                self.deleteLocalData()
            }.done(on: .main) {
                Logger.shared.analytics(.resetKeyn)
                let storyboard: UIStoryboard = UIStoryboard.get(.initialisation)
                AppDelegate.shared.startupService.window?.rootViewController = storyboard.instantiateViewController(withIdentifier: "InitialisationViewController")
            }.catch(on: .main) { error in
                self.showAlert(message: "\("errors.deleting".localized): \(error)")
            }
        }))
        self.present(alert, animated: true, completion: nil)
    }

    @IBAction func deleteData(_ sender: UIButton) {
        let alert = UIAlertController(title: "popups.questions.delete_data".localized, message: "settings.delete_data_warning".localized, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "popups.responses.cancel".localized, style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "popups.responses.delete".localized, style: .destructive, handler: self.deleteRemoteData))
        self.present(alert, animated: true, completion: nil)
    }

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let destination = segue.destination.contents as? WebViewController else {
            return
        }
        let urlPath = Bundle.main.path(forResource: "privacy_policy", ofType: "md")
        destination.url = URL(fileURLWithPath: urlPath!)
    }

    // MARK: - Private functions

    private func deleteRemoteData(action: UIAlertAction) {
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
        firstly {
            when(fulfilled: Seed.deleteBackupData(), TeamSession.deleteAll())
        }.then {
            self.deleteLocalData()
        }.done(on: .main) {
            Logger.shared.analytics(.deleteData)
            let storyboard: UIStoryboard = UIStoryboard.get(.initialisation)
            AppDelegate.shared.startupService.window?.rootViewController = storyboard.instantiateViewController(withIdentifier: "InitialisationViewController")
        }.ensure {
            UIApplication.shared.isNetworkActivityIndicatorVisible = false
        }.catch(on: .main) { error in
            self.showAlert(message: "\("errors.deleting".localized): \(error)")
        }
    }

    private func deleteLocalData() -> Promise<Void> {
        // Browser sessions are gracefully ended
        return firstly {
            BrowserSession.deleteAll()
        }.map {
            // Since we back up the team sessions, we just purge the Keychain
            TeamSession.purgeSessionDataFromKeychain()
            // The corresponding team accounts are deleted here.
            SharedAccount.deleteAll()
            UserAccount.deleteAll()
            SSHIdentity.deleteAll()
        }.then { _ in
            // Deleting endpoint relies on Seed being present
            NotificationManager.shared.unregisterDevice()
        }.map {
            Seed.delete(includeSeed: true)
            Properties.purgePreferences()
        }
    }

}
