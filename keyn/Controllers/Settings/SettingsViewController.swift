/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit

class SettingsViewController: UITableViewController, UITextViewDelegate {

    @IBOutlet weak var notificationSettingSwitch: UISwitch!
    var securityFooterText: String {
        return Seed.paperBackupCompleted ? "settings.backup_completed_footer".localized : "\u{26A0} \("settings.backup_not_finished".localized)."
    }
    @IBOutlet weak var paperBackupAlertIcon: UIImageView!
    @IBOutlet weak var jailbreakWarningTextView: UITextView!
    @IBOutlet weak var jailbreakStackView: UIStackView!
    @IBOutlet weak var jailbreakStackViewHeightConstraint: NSLayoutConstraint!

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.layer.borderColor = UIColor.primaryTransparant.cgColor
        tableView.layer.borderWidth = 1.0
        tableView.separatorColor = UIColor.primaryTransparant
        paperBackupAlertIcon.isHidden = Seed.paperBackupCompleted
        notificationSettingSwitch.isOn = Properties.infoNotifications == .yes
        setJailbreakText()
        NotificationCenter.default.addObserver(forName: .backupCompleted, object: nil, queue: OperationQueue.main, using: updateBackupFooter)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        (tabBarController as! RootViewController).showGradient(true)
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
        // TODO: Test if this fixes the textLabel size on some devices.
        if section == 1 {
            footer.textLabel?.numberOfLines = 3
        }
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
            NotificationManager.shared.subscribe(topic: Properties.notificationTopic) { result in
                DispatchQueue.main.async {
                    let subscribed = NotificationManager.shared.isSubscribed
                    Properties.infoNotifications = subscribed ? .yes : .no
                    if case let .failure(error) = result {
                        sender.isOn = subscribed
                        self.showError(message: "\("errors.subscribing".localized): \(error)")
                    }
                    sender.isUserInteractionEnabled = true
                }
            }
        } else {
            NotificationManager.shared.unsubscribe() { result in
                DispatchQueue.main.async {
                    let subscribed = NotificationManager.shared.isSubscribed
                    Properties.infoNotifications = subscribed ? .yes : .no
                    if case let .failure(error) = result {
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

    private func updateBackupFooter(notification: Notification) {
        tableView.reloadData()
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
        let url = URL(string: "urls.jailbreak".localized)!
        
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
