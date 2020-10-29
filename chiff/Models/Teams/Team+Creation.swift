//
//  Team+Creation.swift
//  chiff
//
//  Created by Bas Doorn on 23/10/2020.
//  Copyright © 2020 keyn. All rights reserved.
//

import Foundation
import PromiseKit

extension Team {

    init(name: String) throws {
        self.seed = try Crypto.shared.generateSeed(length: 32)
        self.id = try Crypto.shared.generateSeed(length: 32).base64
        self.name = name
        let (teamEncryptionKey, teamKeyPair, teamPasswordSeed) = try Self.createTeamSeeds(seed: seed)
        self.encryptionKey = teamEncryptionKey
        self.keyPair = teamKeyPair
        self.passwordSeed = teamPasswordSeed
        self.teamSessionKeys = try TeamSessionKeys()
        self.accounts = Set()
        let user = try self.teamSessionKeys.createAdmin()
        self.users = Set([user])
        self.roles = Set([TeamRole(id: try Crypto.shared.generateRandomId(), name: "Admins", admins: true, users: [user.id])])
    }

    func create(orderKey: String) -> Promise<Session> {
        do {
            let orderKeyPair = try Crypto.shared.createSigningKeyPair(seed: Crypto.shared.convertFromBase64(from: orderKey))
            let orgKey = try Crypto.shared.generateSeed(length: 32) // This key is shared with all team users to retrieve organisational info like PPDs
            let message = try createSignedAPIMessage(orgKey: orgKey)
            return firstly {
                API.shared.signedRequest(path: "organisations/\(orderKeyPair.pubKey.base64)", method: .post, privKey: orderKeyPair.privKey, message: message)
            }.then { (_) -> Promise<TeamSession> in
                do {
                    let session = TeamSession(id: teamSessionKeys.sessionId,
                                       teamId: id,
                                       signingPubKey: teamSessionKeys.signingKeyPair.pubKey,
                                       title: "\("devices.admin".localized) @ \(name)",
                                       version: 2,
                                       isAdmin: true,
                                       created: true,
                                       lastChange: Date.now,
                                       organisationKey: orgKey)
                    try session.save(keys: teamSessionKeys)
                    TeamSession.count += 1
                    return session.backup().map { session }
                } catch is KeychainError {
                    throw SessionError.exists
                } catch is CryptoError {
                    throw SessionError.invalid
                }
            }.then { session in
                BrowserSession.updateAllSessionData(organisationKey: orgKey, organisationType: .team, isAdmin: true).map { session }
            }
        } catch {
            Logger.shared.error("errors.creating_team".localized, error: error)
            return Promise(error: error)
        }
    }

    // MARK: - Private functions

    private func createTeamSession(teamId: String, name: String, orgKey: Data) throws -> TeamSession {
        return TeamSession(id: teamSessionKeys.sessionId,
                           teamId: id,
                           signingPubKey: teamSessionKeys.signingKeyPair.pubKey,
                           title: "\("devices.admin".localized) @ \(name)",
                           version: 2,
                           isAdmin: true,
                           created: true,
                           lastChange: Date.now,
                           organisationKey: orgKey)
    }

    private func createSignedAPIMessage(orgKey: Data) throws -> [String: Any] {
        guard let user = users.first,
              let role = roles.first,
              user.isAdmin,
              role.admins else {
            throw TeamError.inconsistent
        }
        let data = try Crypto.shared.encryptSymmetric(
            JSONSerialization.data(withJSONObject:
                                    ["organisationKey": orgKey.base64],
                                   options: []),
            secretKey: encryptionKey)
            .base64
        let orgKeyPair = try Crypto.shared.createSigningKeyPair(seed: orgKey)
        let message: [String: Any] = [
            "name": name,
            "id": id,
            "data": data,
            "roleId": role.id,
            "userPubkey": user.pubkey!,
            "userId": user.id,
            "userSyncPubkey": user.userSyncPubkey,
            "roleData": try role.encrypt(key: encryptionKey),
            "userData": try user.encrypt(key: encryptionKey),
            "seed": try teamSessionKeys.encrypt(seed: seed),
            "orgPubKey": orgKeyPair.pubKey.base64
        ]
        return [
            "teamPubKey": keyPair.pubKey.base64,
            "signedMessage": try Crypto.shared.sign(message: JSONSerialization.data(withJSONObject: message, options: []), privKey: keyPair.privKey).base64
        ]
    }
}
