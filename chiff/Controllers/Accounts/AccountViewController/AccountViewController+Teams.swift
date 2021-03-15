//
//  AcountViewController+Teams.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import UIKit
import PromiseKit
import ChiffCore

extension AccountViewController {

    func setAddToTeamButton() {
        let teamSessions = try? TeamSession.all()
        if let session = teamSessions?.first(where: { $0.isAdmin }) {
            addToTeamButton.isHidden = false
            addToTeamButton.isEnabled = true
            addToTeamButton.setTitle(account is SharedAccount ? "accounts.move_from_team".localized : "accounts.add_to_team".localized, for: .normal)
            bottomSpacer.frame = CGRect(x: bottomSpacer.frame.minX, y: bottomSpacer.frame.minY, width: bottomSpacer.frame.width, height: 100)
            self.session = session
        } else if let session = teamSessions?.first, account is UserAccount {
            // TODO: Support multiple teams
            addToTeamButton.isHidden = false
            addToTeamButton.isEnabled = true
            addToTeamButton.setTitle("accounts.add_to_team".localized, for: .normal)
            bottomSpacer.frame = CGRect(x: bottomSpacer.frame.minX, y: bottomSpacer.frame.minY, width: bottomSpacer.frame.width, height: 100)
            self.session = session
        } else {
            addToTeamButton.isEnabled = false
            addToTeamButton.isHidden = true
            bottomSpacer.frame = CGRect(x: bottomSpacer.frame.minX, y: bottomSpacer.frame.minY, width: bottomSpacer.frame.width, height: 0)
        }
    }

    // MARK: - Actions

    @IBAction func handleTeamAction(_ sender: KeynButton) {
        guard let session = session else {
            fatalError("Session must exist if this action is called")
        }
        if let account = account as? SharedAccount {
            removeAccountFromTeam(sender, account: account, session: session)
        } else if session.isAdmin {
            addToTeam(sender, session: session)
        } else if let account = account as? UserAccount {
            submitToTeam(sender, account: account, session: session)
        }
    }

    // MARK: - Private functions

    private func showAlert(_ sender: KeynButton, title: String, message: String, handler: @escaping (UIAlertAction) -> Void) {
        let alert = UIAlertController(title: title.localized,
                                      message: message.localized,
                                      preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "popups.responses.cancel".localized, style: .cancel, handler: { _ in
            sender.hideLoading()
        }))
        alert.addAction(UIAlertAction(title: "popups.responses.move".localized, style: .destructive, handler: handler))
        self.present(alert, animated: true, completion: nil)
    }

    private func submitToTeam(_ sender: KeynButton, account: UserAccount, session: TeamSession) {
        showAlert(sender, title: "popups.questions.move_to_team_title",
                  message: "popups.questions.move_to_team_message") { _ in
            sender.showLoading()
            firstly {
                session.submitAccountToTeam(account: account)
            }.ensure(on: .main) {
                sender.hideLoading()
            }.done(on: .main) {
                self.showAlert(message: "Account submitted, admin should authorize")
            }.catch(on: .main) { error in
                self.showAlert(message: "\("errors.add_to_team".localized): \(error)")
            }
        }
    }

    private func addToTeam(_ sender: KeynButton, session: TeamSession) {
        sender.showLoading()
        firstly {
            session.getTeam()
        }.ensure(on: .main) {
            sender.hideLoading()
        }.done(on: .main) {
            self.team = $0
            self.performSegue(withIdentifier: "AddToTeam", sender: self)
        }.catch(on: .main) { error in
            self.showAlert(message: "\("errors.add_to_team".localized): \(error)")
        }
    }

    private func removeAccountFromTeam(_ sender: KeynButton, account: SharedAccount, session: TeamSession) {
        showAlert(sender, title: "popups.questions.move_to_user_account_title",
                  message: "popups.questions.move_to_user_account_message") { _ in
            sender.showLoading()
            firstly {
                session.convertSharedToUserAccount(account: account)
            }.ensure(on: .main) {
                sender.hideLoading()
            }.done {
                self.account = $0
                self.addToTeamButton.originalButtonText = "accounts.add_to_team".localized
            }.catch(on: .main) { error in
                self.showAlert(message: "\("errors.move_from_team".localized): \(error)")
            }
        }
    }

}
