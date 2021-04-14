//
//  AddAccountViewController+TableView.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import UIKit
import PromiseKit
import ChiffCore
import OneTimePassword

extension AddAccountViewController {

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if indexPath.section == 1 && indexPath.row == 2 && token == nil {
            cell.accessoryView = UIImageView(image: UIImage(named: "chevron_right"))
        }
    }

    override func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
        super.tableView(tableView, willDisplayFooterView: view, forSection: section)
        guard let footer = view as? UITableViewHeaderFooterView else {
            return
        }
        if section == 1 {
            footer.textLabel?.isHidden = false
        }
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return indexPath.section == 1 && indexPath.row == 2 && token != nil
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        self.token = nil
        DispatchQueue.main.async {
            self.updateOTPUI()
        }
        tableView.cellForRow(at: indexPath)?.setEditing(false, animated: true)
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return indexPath.section == 2 ? UITableView.automaticDimension : 44
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 1 && indexPath.row == 2 && qrEnabled {
            performSegue(withIdentifier: "showQR", sender: self)
        }
    }

}
