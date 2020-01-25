//
//  SiteTableViewController.swift
//  keyn
//
//  Created by Bas Doorn on 16/04/2019.
//  Copyright © 2019 keyn. All rights reserved.
//

import UIKit

protocol SitesDelegate {
    func updateAccount(account: UserAccount)
}

class SiteTableViewController: UITableViewController, UITextFieldDelegate {

    var editButton: UIBarButtonItem!
    var editingMode: Bool = false
    var account: UserAccount!
    var tap: UITapGestureRecognizer!
    var delegate: SitesDelegate!

    override func viewDidLoad() {
        super.viewDidLoad()
        editButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.edit, target: self, action: #selector(edit))
        navigationItem.rightBarButtonItem = editButton

        tableView.layer.borderColor = UIColor.primaryTransparant.cgColor
        tableView.layer.borderWidth = 1.0
        tableView.separatorColor = UIColor.primaryTransparant
        tap = UITapGestureRecognizer(target: self.view, action: #selector(UIView.endEditing(_:)))
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return tableView.isEditing && account.sites.count > 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return account.sites.count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "accounts.sites_header".localized.capitalizedFirstLetter
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return "accounts.url_warning".localized.capitalizedFirstLetter
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "URLCell", for: indexPath) as! SiteTableViewCell
        cell.websiteURLTextField.text = account.sites[indexPath.row].url
        cell.index = indexPath.row
        cell.websiteURLTextField.delegate = self
        return cell
    }

    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        let header = view as! UITableViewHeaderFooterView
        header.textLabel?.textColor = UIColor.primaryHalfOpacity
        header.textLabel?.font = UIFont.primaryBold
        header.textLabel?.textAlignment = NSTextAlignment.left
        header.textLabel?.frame = header.frame
        header.textLabel?.text = "accounts.sites_header".localized.capitalizedFirstLetter
    }

    override func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
        let footer = view as! UITableViewHeaderFooterView
        footer.textLabel?.textColor = UIColor.textColorHalfOpacity
        footer.textLabel?.font = UIFont.primaryMediumSmall
        footer.textLabel?.textAlignment = NSTextAlignment.left
        footer.textLabel?.frame = footer.frame
        footer.textLabel?.text = "accounts.url_warning".localized.capitalizedFirstLetter
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == UITableViewCell.EditingStyle.delete {
            do {
                let cell = tableView.cellForRow(at: indexPath) as! SiteTableViewCell
                try account.removeSite(forIndex: cell.index)
                tableView.deleteRows(at: [indexPath], with: .automatic)
                delegate.updateAccount(account: account)
            } catch {
                showAlert(message: "errors.delete_url".localized.capitalizedFirstLetter)
            }
        }
    }

    // MARK: - UITextFieldDelegate

    // Hide the keyboard.
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        view.addGestureRecognizer(tap)
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        view.removeGestureRecognizer(tap)
    }

    // MARK: - Editing functions

    @objc func edit() {
        tableView.setEditing(true, animated: true)
        let doneButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.done, target: self, action: #selector(update))
        doneButton.style = .done

        navigationItem.setRightBarButton(doneButton, animated: true)

        editingMode = true
        UIView.transition(with: tableView,
                          duration: 0.1,
                          options: .transitionCrossDissolve,
                          animations: { self.tableView.reloadData() })
    }

    @objc func update() {
        endEditing()
        do {
            for cell in tableView.visibleCells.map({ $0 as! SiteTableViewCell }) {
                if cell.isChanged, let index = tableView.indexPath(for: cell)?.row, let newUrl = cell.websiteURLTextField.text {
                    try account.updateSite(url: newUrl, forIndex: index)
                    delegate.updateAccount(account: account)
                    cell.isChanged = false
                }
            }
        } catch {
            Logger.shared.warning("Could not change username", error: error)
        }
    }

    private func endEditing() {
        tableView.setEditing(false, animated: true)
        navigationItem.setRightBarButton(editButton, animated: true)
        editingMode = false
    }

}
