//
//  AccountViewController+TableView.swift
//  chiff
//
//  Created by Bas Doorn on 23/10/2020.
//  Copyright © 2020 keyn. All rights reserved.
//

import UIKit
import PromiseKit

extension AccountViewController {

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if (indexPath.section == 1 && indexPath.row == 2 && token == nil) || (indexPath.section == 0 && indexPath.row == 1 && account.sites.count > 1) {
            cell.accessoryView = UIImageView(image: UIImage(named: "chevron_right"))
        }
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return editingMode ? 4 : 3
    }

    override func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
        super.tableView(tableView, willDisplayFooterView: view, forSection: section)
        guard let footer = view as? UITableViewHeaderFooterView else {
            return
        }
        switch section {
        case 0:
            footer.textLabel?.isHidden = !(shadowing || webAuthnEnabled || tableView.isEditing)
        case 1:
            footer.textLabel?.isHidden = false
        case 2:
            footer.textLabel?.isHidden = false
        case 3:
            footer.textLabel?.isHidden = false
        default:
            fatalError("An extra section appeared!")
        }
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return indexPath.section == 1 && indexPath.row == 2 && token != nil && tableView.isEditing && account is UserAccount
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        guard var account = self.account as? UserAccount else {
            fatalError("Should not be able to edit sharedAccount")
        }
        try? account.deleteOtp()
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
        if indexPath.section == 0 {
            if indexPath.row == 1 && account.sites.count > 1 && account is UserAccount {
                performSegue(withIdentifier: "ShowSiteOverview", sender: self)
            }
        } else if indexPath.section == 1 {
            if (indexPath.row == 1 || (indexPath.row == 2 && !qrEnabled)) && password != nil {
                copyToPasteboard(indexPath)
            } else if indexPath.row == 2 && qrEnabled && account is UserAccount {
                performSegue(withIdentifier: "showQR", sender: self)
            }
        }
    }

    // MARK: - Private functions

    private func copyToPasteboard(_ indexPath: IndexPath) {
        guard let cell = tableView.cellForRow(at: indexPath) else {
            return
        }

        if indexPath.row == 1 {
            Logger.shared.analytics(.passwordCopied)
        } else {
            Logger.shared.analytics(.otpCopied)
        }

        let pasteBoard = UIPasteboard.general
        pasteBoard.string = indexPath.row == 1 ? userPasswordTextField.text : userCodeTextField.text

        let copiedLabel = UILabel(frame: cell.bounds)
        copiedLabel.text = "accounts.copied".localized
        copiedLabel.font = copiedLabel.font.withSize(18)
        copiedLabel.textAlignment = .center
        copiedLabel.textColor = .white
        copiedLabel.backgroundColor = UIColor(displayP3Red: 0.85, green: 0.85, blue: 0.85, alpha: 1)

        cell.addSubview(copiedLabel)

        UIView.animate(withDuration: 0.5, delay: 1.0, options: [.curveLinear], animations: {
            copiedLabel.alpha = 0.0
        }, completion: { result in
            if result {
                copiedLabel.removeFromSuperview()
            }
        })
    }

}
