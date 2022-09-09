//
//  AboutViewController.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import UIKit
import ChiffCore

class AboutViewController: UITableViewController {

    @IBOutlet weak var versionLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.layer.borderColor = UIColor.primaryTransparant.cgColor
        tableView.layer.borderWidth = 1.0
        tableView.separatorColor = UIColor.primaryTransparant
        setVersionText()
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0: return "settings.legal".localized
        case 1: return "settings.help".localized
        default: fatalError("Too many sections")
        }
    }

    // This gets overridden by willDisplayFooterView, but this sets the correct height
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return section == 1 ? "settings.feedback_footer".localized : nil
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
        switch section {
        case 0: header.textLabel?.text = "settings.legal".localized
        case 1: header.textLabel?.text = "settings.help".localized
        default: fatalError("Too many sections")
        }
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
        footer.textLabel?.text = section == 1 ? "settings.feedback_footer".localized : nil
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 0 && indexPath.row == 0 {
            let urlPath = Bundle.main.path(forResource: "terms_of_use", ofType: "md")
            performSegue(withIdentifier: "ShowWebView", sender: URL(fileURLWithPath: urlPath!))
        } else if indexPath.section == 0 && indexPath.row == 1 {
            let urlPath = Bundle.main.path(forResource: "privacy_policy", ofType: "md")
            performSegue(withIdentifier: "ShowWebView", sender: URL(fileURLWithPath: urlPath!))
        } else if indexPath.section == 1 && indexPath.row == 1 {
            performSegue(withIdentifier: "ShowWebView", sender: URL(string: "urls.faq".localized))
        }
    }

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let destination = segue.destination as? WebViewController, let url = sender as? URL {
            destination.url = url
        }
    }

    // MARK: - Private functions

    private func setVersionText() {
        if let version = Properties.version {

            let versionText = Properties.environment == .staging ?
                "\("settings.version".localized.capitalizedFirstLetter) \(version)-beta" :
                "\("settings.version".localized.capitalizedFirstLetter) \(version)"
            versionLabel.text = "© \(Calendar.current.component(.year, from: Date())) Chiff B.V.\n\(versionText)"
        }
    }

}
