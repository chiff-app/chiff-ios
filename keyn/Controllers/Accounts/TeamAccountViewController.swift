//
//  TeamAccountViewController.swift
//  keyn
//
//  Created by Bas Doorn on 11/03/2020.
//  Copyright © 2020 keyn. All rights reserved.
//

import UIKit
import PromiseKit

protocol AccessControlDelegate {
    func setObjects(objects: [AccessControllable], type: AccessControlType)
}

class TeamAccountViewController: KeynTableViewController, AccessControlDelegate {

    override var headers: [String?] {
        return [
            "accounts.convert_to_team_header".localized
        ]
    }

    override var footers: [String?] {
        return [
            "accounts.convert_to_team_footer".localized
        ]
    }

    var session: TeamSession!
    var account: Account!
    var team: Team!

    var selectedUsers = [TeamUser]()
    var selectedRoles = [TeamRole]()

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var teamLogo: UIImageView!

    override func viewDidLoad() {
        super.viewDidLoad()
        teamLogo.image = session.logo ?? UIImage(named: "logo_purple")
        setTitle()
    }

    func setObjects(objects: [AccessControllable], type: AccessControlType) {
        switch type {
        case .user:
            selectedUsers = objects as! [TeamUser]
        case .role:
            selectedRoles = objects as! [TeamRole]
        }
        tableView.reloadData()
    }

    // MARK: - Actions

    @IBAction func save(_ sender: UIBarButtonItem) {
        convertToTeamAccount()
    }

    // MARK: - Table view data source


    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if indexPath.row == 0 {
            switch selectedRoles.count {
            case let x where x == 1: cell.textLabel?.text = selectedRoles.first!.name
            case let x where x > 1: cell.textLabel?.text = String(format: "accounts.number_of_roles".localized, "\(selectedRoles.count)")
            default: cell.textLabel?.text = "accounts.add_role".localized
            }
        } else {
            switch selectedUsers.count {
            case let x where x == 1: cell.textLabel?.text = selectedUsers.first!.name
            case let x where x > 1: cell.textLabel?.text = String(format: "accounts.number_of_users".localized, "\(selectedUsers.count)")
            default: cell.textLabel?.text = "accounts.add_user".localized
            }
        }
    }


    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let destination = segue.destination as? TeamAccessControlViewController else {
            return
        }
        destination.delegate = self
        switch segue.identifier {
        case "AddUser":
            destination.allObjects = Array(team.users)
            destination.type = .user
            destination.selectedObjects = selectedUsers
        case "AddRole":
            destination.allObjects = Array(team.roles)
            destination.type = .role
            destination.selectedObjects = selectedRoles
        default: return
        }
    }

    // MARK: - Private functions

    private func setTitle() {
        let titleText = String(format: "accounts.convert_to_team_title".localized, account.site.name, team.name)
        let siteNameRange = (titleText as NSString).range(of: account.site.name)
        let teamNameRange = (titleText as NSString).range(of: team.name)
        let attributedString = NSMutableAttributedString(string: titleText)
        attributedString.addAttribute(.foregroundColor, value: UIColor.secondary as Any, range: siteNameRange)
        attributedString.addAttribute(.foregroundColor, value: UIColor.secondary as Any, range: teamNameRange)
        titleLabel.attributedText = attributedString
    }

    private func convertToTeamAccount() {
        let barButtonItem = navigationItem.rightBarButtonItem as? LocalizableBarButton
        do {
            let teamAccount = try TeamAccount(account: account, seed: team.passwordSeed, users: selectedUsers, roles: selectedRoles)
            let ciphertext = try teamAccount.encrypt(key: team.encryptionKey)
            let message: [String: Any] = [
                "httpMethod": APIMethod.post.rawValue,
                "timestamp": String(Int(Date().timeIntervalSince1970)),
                "id": teamAccount.id,
                "data": ciphertext,
                "updateUsers": try team.usersForAccount(account: teamAccount),
                "deleteUsers": []
            ]
            let jsonData = try JSONSerialization.data(withJSONObject: message, options: [])
            let signature = try Crypto.shared.signature(message: jsonData, privKey: team.keyPair.privKey).base64
            barButtonItem?.showLoading()
            firstly {
                API.shared.request(path: "teams/\(team.id)/accounts/\(teamAccount.id)", parameters: nil, method: .post, signature: signature, body: jsonData)
            }.then { _ in
                self.account.delete()
            }.then { _ in
                TeamSession.updateTeamSession(session: self.session, pushed: false).asVoid()
            }.done(on: .main) {
                self.performSegue(withIdentifier: "DeleteUserAccount", sender: self)
            }.catch(on: .main) { error in
                barButtonItem?.hideLoading()
                self.showAlert(message: "\("errors.convert_to_team".localized): \(error.localizedDescription)")
            }
        } catch AccountError.notTOTP {
            barButtonItem?.hideLoading()
            self.showAlert(message: "errors.convert_to_team_totp".localized)
        } catch {
            barButtonItem?.hideLoading()
            self.showAlert(message: "\("errors.convert_to_team".localized): \(error.localizedDescription)")
        }
    }

}
