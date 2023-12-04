//
//  SettingsViewController.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import UIKit
import PromiseKit
import ChiffCore
import LinkPresentation

class SettingsViewController: UITableViewController, UITextViewDelegate {

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

        setJailbreakText()
        NotificationCenter.default.addObserver(self, selector: #selector(updateBackupFooter(notification:)), name: .backupCompleted, object: nil)
    }

    // MARK: - UITableView

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "settings.settings".localized
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.row == 0 && indexPath.section == 0 && !Properties.hasFaceID {
            return 0.5
        }
        return 44
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return securityFooterText
    }

    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        guard let header = view as? UITableViewHeaderFooterView else {
            Logger.shared.error("Expected UITableViewHeaderFooterView, but found \(type(of: view)).")
            return
        }
        header.textLabel?.textColor = UIColor.primaryHalfOpacity
        header.textLabel?.font = UIFont.primaryBold
        header.textLabel?.textAlignment = NSTextAlignment.left
        header.textLabel?.frame = header.frame
        header.textLabel?.text = "settings.settings".localized
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
        footer.textLabel?.text = securityFooterText
        footer.textLabel?.numberOfLines = 3
    }

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if let cell = cell as? AccessoryTableViewCell, indexPath.row == 3, #available(iOS 13.0, *) {
            cell.accessoryView = UIImageView(image: UIImage(systemName: "square.and.arrow.up"))
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.row == 3 {
            let activityViewController = UIActivityViewController(activityItems: [self], applicationActivities: nil)
            activityViewController.excludedActivityTypes = [.addToReadingList, .assignToContact, .markupAsPDF, .openInIBooks, .saveToCameraRoll]
            present(activityViewController, animated: true, completion: nil)
        }
    }

    // MARK: - Navigation

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

    @objc private func updateBackupFooter(notification: Notification) {
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
            ], range: NSRange(location: jailbreakWarning.count + 2, length: readMore.count))
        jailbreakWarningTextView.attributedText = attributedString
        jailbreakWarningTextView.linkTextAttributes = [
            .foregroundColor: UIColor.primary
        ]
    }

}

extension SettingsViewController: UIActivityItemSource {

    var url: URL {
        return URL(string: "https://ios.chiff.app")!
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        return url
    }

    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        if activityType == .airDrop {
            return URL(string: "https://apps.apple.com/app/id1361749715")!
        }
        return "settings.share_text".localized
    }

    func activityViewController(_ activityViewController: UIActivityViewController, subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
        return "Chiff"
    }

    @available(iOS 13.0, *)
    func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.title = "Chiff"
        metadata.imageProvider =
            NSItemProvider.init(contentsOf:
            Bundle.main.url(forResource: "logo", withExtension: "png"))
        return metadata
    }
}
