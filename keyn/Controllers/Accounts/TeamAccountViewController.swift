//
//  TeamAccountViewController.swift
//  keyn
//
//  Created by Bas Doorn on 11/03/2020.
//  Copyright © 2020 keyn. All rights reserved.
//

import UIKit

class TeamAccountViewController: UIViewController {

    var session: TeamSession!
    var account: Account!
    var team: Team!

    override func viewDidLoad() {
        super.viewDidLoad()
        convertToTeamAccount()
        // Do any additional setup after loading the view.
    }

    func convertToTeamAccount() {
        do {
            // Some users
            // Some roles
            let role = team.roles.first(where: { $0.admins })!.id
            let teamAccount = try TeamAccount(account: account, seed: team.passwordSeed, users: [], roles: [role])
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
            API.shared.request(path: "teams/\(team.keyPair.pubKey.base64)/accounts/\(teamAccount.id)", parameters: nil, method: .post, signature: signature, body: jsonData) { (result) in
                switch result {
                case .success(_):
                    self.account.delete { (result) in
                        switch result {
                        case .success(_):
                            TeamSession.updateTeamSession(session: self.session, pushed: false) { (result) in
                                if case .failure(let error) = result {
                                    print(error)
                                }
                            }
                        case .failure(let error):
                            print(error)
                        }
                    }
                case .failure(let error):
                    print(error)
                }
            }
        } catch {
            Logger.shared.error("Error converting account to team account", error: error)
        }
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
