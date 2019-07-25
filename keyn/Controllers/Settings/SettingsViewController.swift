/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit

class SettingsViewController: UITableViewController, UITextViewDelegate {

    @IBOutlet weak var notificationSettingSwitch: UISwitch!
    var securityFooterText = "\u{26A0} \("settings.backup_not_finished".localized)."
    var justLoaded = true
    @IBOutlet weak var paperBackupAlertIcon: UIImageView!
    @IBOutlet weak var versionLabel: UILabel!
    @IBOutlet weak var jailbreakWarningTextView: UITextView!

    override func viewDidLoad() {
        super.viewDidLoad()
        setFooterText()
        tableView.layer.borderColor = UIColor.primaryTransparant.cgColor
        tableView.layer.borderWidth = 1.0
        tableView.separatorColor = UIColor.primaryTransparant
        paperBackupAlertIcon.isHidden = Seed.paperBackupCompleted
        notificationSettingSwitch.isOn = Properties.infoNotifications == .yes
        setVersionText()
        setJailbreakText()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        (tabBarController as! RootViewController).showGradient(false)
        if !justLoaded {
            setFooterText()
        } else { justLoaded = false }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return section == 0 ? "settings.settings".localized : nil
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return section == 0 ? securityFooterText : nil
    }

    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        let header = view as! UITableViewHeaderFooterView
        header.textLabel?.textColor = UIColor.primaryHalfOpacity
        header.textLabel?.font = UIFont.primaryBold
        header.textLabel?.textAlignment = NSTextAlignment.left
        header.textLabel?.frame = header.frame
        header.textLabel?.text = section == 0 ? "settings.settings".localized : nil
    }

    override func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
        guard section == 0 else {
            return
        }
        let footer = view as! UITableViewHeaderFooterView
        footer.textLabel?.textColor = UIColor.textColorHalfOpacity
        footer.textLabel?.font = UIFont.primaryMediumSmall
        footer.textLabel?.textAlignment = NSTextAlignment.left
        footer.textLabel?.frame = footer.frame
        footer.textLabel?.text = section == 0 ? securityFooterText : nil
        footer.textLabel?.numberOfLines = footer.textLabel!.text!.count > 60 ? 2 : 1
    }

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if (indexPath.section == 0 && indexPath.row >= 1) || indexPath.section == 1 {
            cell.accessoryView = UIImageView(image: UIImage(named: "chevron_right"))
        }
    }
    // MARK: - Actions

    @IBAction func updateNotificationSettings(_ sender: UISwitch) {
        sender.isUserInteractionEnabled = false
        if sender.isOn {
            NotificationManager.shared.subscribe(topic: Properties.notificationTopic) { error in
                DispatchQueue.main.async {
                    let subscribed = NotificationManager.shared.isSubscribed
                    Properties.infoNotifications = subscribed ? .yes : .no
                    if let error = error {
                        sender.isOn = subscribed
                        self.showError(message: "\("errors.subscribing".localized): \(error)")
                    }
                    sender.isUserInteractionEnabled = true
                }
            }
        } else {
            NotificationManager.shared.unsubscribe() { error in
                DispatchQueue.main.async {
                    let subscribed = NotificationManager.shared.isSubscribed
                    Properties.infoNotifications = subscribed ? .yes : .no
                    if let error = error {
                        sender.isOn = subscribed
                        self.showError(message: "\("errors.unsubscribing".localized): \(error)")
                    }
                    sender.isUserInteractionEnabled = true
                }
            }
        }
    }

    @IBAction func unwindToSettings(sender: UIStoryboardSegue) {
        let completed = Seed.paperBackupCompleted
        paperBackupAlertIcon.isHidden = completed
        if let rootController = tabBarController as? RootViewController {
            rootController.setBadge(completed: completed)
        }
    }

    // MARK: - UITextViewDelegate

    func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange) -> Bool {
        UIApplication.shared.open(URL, options: [:], completionHandler: nil)
        return false
    }

    // MARK: - Private

    private func setFooterText() {
        tableView.reloadSections(IndexSet(integer: 0), with: .none)
        securityFooterText = "settings.backup_completed_footer".localized
    }

    private func setVersionText() {
        if let version = Properties.version, let build = Properties.build {
            versionLabel.text = Properties.environment == .beta ? "Keyn \(version)-beta (\(build))" : "Keyn \(version) (\(build))"
        }
    }

    private func setJailbreakText() {
        guard Properties.isJailbroken else {
            jailbreakWarningTextView.isHidden = true
            return
        }
        jailbreakWarningTextView.isHidden = false
        jailbreakWarningTextView.delegate = self
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let readMore = "settings.read_more".localized
        let jailbreakWarning = "settings.jailbreak_warning".localized
        let attributedString = NSMutableAttributedString(string: "\(jailbreakWarning). \(readMore)", attributes: [
            .paragraphStyle: paragraph,
            .foregroundColor: UIColor.red,
            .font: UIFont.primaryMediumNormal!
            ])
        let url = URL(string: "https://keyn.app/faq")!
        
        attributedString.setAttributes([
            .link: url,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .font: UIFont.primaryMediumNormal!
            ], range: NSMakeRange(jailbreakWarning.count + 2, readMore.count))
        jailbreakWarningTextView.attributedText = attributedString
        jailbreakWarningTextView.linkTextAttributes = [
            .foregroundColor: UIColor.primary
        ]
    }
}
