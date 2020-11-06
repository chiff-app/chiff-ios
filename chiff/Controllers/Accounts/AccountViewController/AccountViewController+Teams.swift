//
//  AcountViewController+Teams.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import UIKit
import PromiseKit

extension AccountViewController {

    func setAddToTeamButton() {
        if let session = (try? TeamSession.all())?.first(where: { $0.isAdmin }) {
            addToTeamButton.isHidden = false
            addToTeamButton.isEnabled = true
            addToTeamButton.setTitle(account is SharedAccount ? "accounts.move_from_team".localized : "accounts.add_to_team".localized, for: .normal)
            bottomSpacer.frame = CGRect(x: bottomSpacer.frame.minX, y: bottomSpacer.frame.minY, width: bottomSpacer.frame.width, height: 100)
            self.session = session
        } else {
            addToTeamButton.isEnabled = false
            addToTeamButton.isHidden = true
            bottomSpacer.frame = CGRect(x: bottomSpacer.frame.minX, y: bottomSpacer.frame.minY, width: bottomSpacer.frame.width, height: 0)
        }
    }

    // MARK: - Actions

    @IBAction func addToTeam(_ sender: KeynButton) {
        sender.showLoading()
        guard let session = session else {
            fatalError("Session must exist if this action is called")
        }
        if let account = account as? SharedAccount {
            let alert = UIAlertController(title: "popups.questions.move_to_user_account_title".localized,
                                          message: "popups.questions.move_to_user_account_message".localized,
                                          preferredStyle: .actionSheet)
            alert.addAction(UIAlertAction(title: "popups.responses.cancel".localized, style: .cancel, handler: { _ in
                sender.hideLoading()
            }))
            alert.addAction(UIAlertAction(title: "popups.responses.move".localized, style: .destructive, handler: { _ in
                firstly {
                    self.removeAccountFromTeam(session: session, account: account)
                }.ensure {
                    sender.hideLoading()
                }.catch(on: .main) { error in
                    self.showAlert(message: "\("errors.move_from_team".localized): \(error)")
                }
            }))
            self.present(alert, animated: true, completion: nil)
        } else {
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
    }

    // MARK: - Private functions

    private func removeAccountFromTeam(session: TeamSession, account: SharedAccount) -> Promise<Void> {
        do {
            let password = try account.password()
            let notes = try account.notes()
            return firstly {
                session.getTeam()
            }.then {
                $0.deleteAccount(id: account.id)
            }.then {
                TeamSession.updateTeamSession(session: session).asVoid()
            }.map(on: .main) {
                guard try SharedAccount.get(id: account.id, context: nil) == nil else {
                    throw KeychainError.storeKey
                }
                self.account = try UserAccount(username: account.username, sites: account.sites, password: password, rpId: nil, algorithms: nil, notes: notes, askToChange: nil, context: nil)
                self.addToTeamButton.originalButtonText = "accounts.add_to_team".localized
            }.asVoid()
        } catch {
            return Promise(error: error)
        }
    }

}
