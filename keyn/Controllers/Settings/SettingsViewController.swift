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
    @IBOutlet weak var jailbreakWarningTextView: UITextView!
    @IBOutlet weak var jailbreakStackView: UIStackView!
    @IBOutlet weak var jailbreakStackViewHeightConstraint: NSLayoutConstraint!

    override func viewDidLoad() {
        super.viewDidLoad()
        setFooterText()
        tableView.layer.borderColor = UIColor.primaryTransparant.cgColor
        tableView.layer.borderWidth = 1.0
        tableView.separatorColor = UIColor.primaryTransparant
        paperBackupAlertIcon.isHidden = Seed.paperBackupCompleted
        notificationSettingSwitch.isOn = Properties.infoNotifications == .yes
        setJailbreakText()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        (tabBarController as! RootViewController).showGradient(true)
        if !justLoaded {
            setFooterText()
        } else { justLoaded = false }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0: return "settings.premium".localized
        case 1: return "settings.settings".localized
        default: fatalError("Too many sections")
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if Properties.environment == .beta {
            return section == 1 ? securityFooterText : "settings.premium_beta".localized
        } else {
            return section == 1 ? securityFooterText : nil
        }
    }

    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        let header = view as! UITableViewHeaderFooterView
        header.textLabel?.textColor = UIColor.primaryHalfOpacity
        header.textLabel?.font = UIFont.primaryBold
        header.textLabel?.textAlignment = NSTextAlignment.left
        header.textLabel?.frame = header.frame
        switch section {
            case 0: header.textLabel?.text = "settings.premium".localized
            case 1: header.textLabel?.text = "settings.settings".localized
            default: fatalError("Too many sections")
        }
    }

    override func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
        guard section == 1 || Properties.environment == .beta else {
            return
        }
        let footer = view as! UITableViewHeaderFooterView
        footer.textLabel?.textColor = UIColor.textColorHalfOpacity
        footer.textLabel?.font = UIFont.primaryMediumSmall
        footer.textLabel?.textAlignment = NSTextAlignment.left
        footer.textLabel?.frame = footer.frame
        footer.textLabel?.text = (Properties.environment == .beta && section == 0) ? "settings.premium_beta".localized : securityFooterText
        footer.textLabel?.numberOfLines = footer.textLabel!.text!.count > 60 ? 2 : 1
    }

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if indexPath.section == 0 && indexPath.row == 0 && Properties.environment == .beta, let cell = cell as? AccessoryTableViewCell {
            cell.enabled = false
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
        tableView.reloadSections(IndexSet(integer: 1), with: .none)
        securityFooterText = "settings.backup_completed_footer".localized
    }

    private func setJailbreakText() {
        guard Properties.isJailbroken else {
            jailbreakStackViewHeightConstraint.constant = 0
            jailbreakStackView.isHidden = true
            return
        }
        jailbreakStackViewHeightConstraint.constant = 50
        jailbreakStackView.isHidden = false
        jailbreakWarningTextView.delegate = self
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .left
        let readMore = "settings.read_more".localized
        let jailbreakWarning = "settings.jailbreak_warning".localized
        let attributedString = NSMutableAttributedString(string: "\(jailbreakWarning). \(readMore)", attributes: [
            .paragraphStyle: paragraph,
            .foregroundColor: UIColor.primary,
            .font: UIFont.primaryMediumNormal!
            ])
        let url = URL(string: "https://keyn.app/faq#jailbreak")!
        
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
