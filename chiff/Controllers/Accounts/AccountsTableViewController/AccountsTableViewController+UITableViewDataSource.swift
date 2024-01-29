//
//  AcountsTableViewController+DataSource.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import UIKit
import ChiffCore

extension AccountsTableViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let accounts = filteredAccounts else {
            return 0
        }
        return accounts.count
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let account = filteredAccounts[indexPath.row] as? Account {
            performSegue(withIdentifier: "ShowAccount", sender: account)
        } else if let identity = filteredAccounts[indexPath.row] as? SSHIdentity {
            performSegue(withIdentifier: "ShowDeveloperIdentity", sender: identity)
        }
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        let account = filteredAccounts[indexPath.row]
        return !(account is SharedAccount)
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        guard editingStyle == UITableViewCell.EditingStyle.delete else {
            return
        }
        let alert = UIAlertController(title: "popups.questions.delete_account".localized, message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "popups.responses.cancel".localized, style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "popups.responses.delete".localized, style: .destructive, handler: { _ in
            let account = self.filteredAccounts![indexPath.row]
            self.deleteAccount(account: account, filteredIndexPath: indexPath)
        }))
        self.present(alert, animated: true, completion: nil)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var identifier: String!
        switch filteredAccounts[indexPath.row] {
        case is SharedAccount:
            identifier = "TeamsCell"
        case is SSHIdentity:
            identifier = "SSHCell"
        case let account as UserAccount:
            identifier = account.shadowing ? "ShadowingCell" : "AccountCell"
        default:
            identifier = "AccountCell"
        }
        return tableView.dequeueReusableCell(withIdentifier: identifier, for: indexPath)
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let cell = cell as? AccountTableViewCell else {
            return
        }
        let account = filteredAccounts[indexPath.row]
        cell.titleLabel.text = account.name
        if #available(iOS 13.0, *), let cell = cell as? SharedAccountTableViewCell {
            cell.teamIcon.image = UIImage(systemName: "person.2.fill")
        }
    }

}
