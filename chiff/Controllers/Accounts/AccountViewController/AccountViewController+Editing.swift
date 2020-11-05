//
//  AccountViewController+Editing.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import UIKit
import MBProgressHUD
import OneTimePassword
import QuartzCore
import PromiseKit

extension AccountViewController {

    func initializeEditing() {
        editButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.edit, target: self, action: #selector(edit))
        editButton.isEnabled = account is UserAccount
        navigationItem.rightBarButtonItem = editButton
        tap = UITapGestureRecognizer(target: self.view, action: #selector(UIView.endEditing(_:)))
    }

    @objc func edit() {
        tableView.setEditing(true, animated: true)
        let doneButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.done, target: self, action: #selector(update))
        doneButton.style = .done

        navigationItem.setRightBarButton(doneButton, animated: true)
        reEnableBarButtonFont()

        userNameTextField.isEnabled = true
        userPasswordTextField.isEnabled = true
        websiteNameTextField.isEnabled = true
        websiteURLTextField.isEnabled = true
        notesCell.textView.isEditable = true
        totpLoader?.isHidden = true

        editingMode = true
        UIView.transition(with: tableView,
                          duration: 0.1,
                          options: .transitionCrossDissolve,
                          animations: { self.tableView.reloadData() })
    }

    @objc func cancel() {
        endEditing()
        userPasswordTextField.text = password ?? "22characterplaceholder"
        userNameTextField.text = account?.username
        websiteNameTextField.text = account?.site.name
        websiteURLTextField.text = account?.site.url
    }

    @objc func update() {
        guard let account = self.account as? UserAccount else {
            return
        }
        endEditing()
        do {
            if LocalAuthenticationManager.shared.isAuthenticated {
                try updateUserAccount(account: account)
            } else {
                firstly {
                    LocalAuthenticationManager.shared.authenticate(reason: String(format: "popups.questions.update_account".localized, account.site.name), withMainContext: true)
                }.map(on: .main) { _ in
                    try self.updateUserAccount(account: account)
                }.catch(on: .main) { error in
                    self.showAlert(message: "errors.updating_account".localized)
                    self.userNameTextField.text = account.username
                    self.websiteNameTextField.text = account.site.name
                    self.websiteURLTextField.text = account.site.url
                    Logger.shared.error("Error loading accountData", error: error)
                }
            }
        } catch {
            Logger.shared.warning("Could not change username", error: error)
            userNameTextField.text = account.username
            websiteNameTextField.text = account.site.name
            websiteURLTextField.text = account.site.url
        }
    }

    func endEditing() {
        tableView.setEditing(false, animated: true)
        userPasswordTextField.isSecureTextEntry = true
        navigationItem.setRightBarButton(editButton, animated: true)
        userNameTextField.isEnabled = false
        userPasswordTextField.isEnabled = false
        websiteNameTextField.isEnabled = false
        websiteURLTextField.isEnabled = false
        notesCell.textView.isEditable = false
        totpLoader?.isHidden = false

        editingMode = false
        UIView.transition(with: tableView,
                          duration: 0.1,
                          options: .transitionCrossDissolve,
                          animations: { self.tableView.reloadData() })
    }

    // MARK: - Private methods

    private func updateUserAccount(account: UserAccount) throws {
        var account = account
        var newPassword: String?
        let newUsername = userNameTextField.text != account.username ? userNameTextField.text : nil
        let newSiteName = websiteNameTextField.text != account.site.name ? websiteNameTextField.text : nil
        if let oldPassword: String = password {
            newPassword = userPasswordTextField.text != oldPassword ? userPasswordTextField.text : nil
        } else {
            newPassword = userPasswordTextField.text
        }
        let newUrl = websiteURLTextField.text != account.site.url ? websiteURLTextField.text : nil
        if try notesCell.textString != account.notes() {
            try account.updateNotes(notes: notesCell.textString)
        }
        guard newPassword != nil || newUsername != nil || newSiteName != nil || newUrl != nil else {
            return
        }
        try account.update(username: newUsername, password: newPassword, siteName: newSiteName, url: newUrl, askToLogin: nil, askToChange: nil)
        NotificationCenter.default.postMain(name: .accountUpdated, object: self, userInfo: ["account": account])
        if newPassword != nil {
            showPasswordButton.isHidden = false
            showPasswordButton.isEnabled = true
        }
        Logger.shared.analytics(.accountUpdated, properties: [
            .username: newUsername != nil,
            .password: newPassword != nil,
            .url: newUrl != nil,
            .siteName: newSiteName != nil
        ])
    }

}
