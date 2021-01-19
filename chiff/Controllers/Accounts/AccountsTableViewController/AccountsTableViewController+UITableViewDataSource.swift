//
//  AcountsTableViewController+DataSource.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import UIKit

extension AccountsTableViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let accounts = filteredAccounts else {
            return 0
        }
        return accounts.count
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        let account = filteredAccounts[indexPath.row]
        return account is UserAccount
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
        return tableView.dequeueReusableCell(withIdentifier: "AccountCell", for: indexPath)
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let cell = cell as? AccountTableViewCell else {
            return
        }
        let account = filteredAccounts[indexPath.row]
        cell.titleLabel.text = account.site.name
        if #available(iOS 13.0, *) {
            cell.teamIcon.image = UIImage(systemName: "person.2.fill")
        }
        if account is SharedAccount {
            cell.teamIconWidthConstraint.constant = 24
        } else if let account = account as? UserAccount, account.shadowing {
            cell.teamIconWidthConstraint.constant = 24
            cell.teamIcon.alpha = 0.5
        } else {
            cell.teamIconWidthConstraint.constant = 0
        }
    }

}
