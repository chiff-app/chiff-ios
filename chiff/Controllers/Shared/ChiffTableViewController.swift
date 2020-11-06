//
//  ChiffTableViewController.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import UIKit

class ChiffTableViewController: UITableViewController {

    /// Set the header text for each section index and it will be automatically formatted in Chiff style.
    var headers: [String?] {
        return []
    }

    /// Set the footer text for each section index and it will be automatically formatted in Chiff style.
    var footers: [String?] {
        return []
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return headers[safe: section] ?? nil
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if let footerText = footers[safe: section], let text = footerText {
            return text
        } else {
            return nil
        }
    }

    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if let headerText = headers[safe: section],
           let text = headerText,
           let header = view as? UITableViewHeaderFooterView {
            header.textLabel?.textColor = UIColor.primaryHalfOpacity
            header.textLabel?.font = UIFont.primaryBold
            header.textLabel?.textAlignment = NSTextAlignment.left
            header.textLabel?.frame = header.frame
            header.textLabel?.text = text
        }
    }

    override func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
        if let footerText = footers[safe: section],
           let text = footerText,
           let footer = view as? UITableViewHeaderFooterView {
            footer.textLabel?.textColor = UIColor.textColorHalfOpacity
            footer.textLabel?.font = UIFont.primaryMediumSmall
            footer.textLabel?.textAlignment = NSTextAlignment.left
            footer.textLabel?.frame = footer.frame
            footer.textLabel?.text = text
        }
    }

}
