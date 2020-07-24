//
//  Team.swift
//  keyn
//
//  Created by Bas Doorn on 07/02/2020.
//  Copyright © 2020 keyn. All rights reserved.
//

import Foundation
import PromiseKit

struct Team {

    let roles: Set<TeamRole>
    let users: Set<TeamUser>
    let accounts: Set<TeamAccount>
    let name: String
    let encryptionKey: Data
    let passwordSeed: Data
    let keyPair: KeyPair

    static let CRYPTO_CONTEXT = "keynteam"
    static let TEAM_SEED_CONTEXT = "teamseed"

    static func create(orderKey: String, name: String) -> Promise<(Session, String)> {
        do {
            // Generate seeds
            let orderKeyPair = try Crypto.shared.createSigningKeyPair(seed: Crypto.shared.convertFromBase64(from: orderKey))
            let teamSeed = try Crypto.shared.generateSeed(length: 32)
            let (teamEncryptionKey, teamKeyPair, _) = try createTeamSeeds(seed: teamSeed)
            let orgKey = try Crypto.shared.generateSeed(length: 32) // This key is shared with all team users to retrieve organisational info like PPDs
            let orgKeyPair = try Crypto.shared.createSigningKeyPair(seed: orgKey)

            // Create admin user
            let browserKeyPair = try Crypto.shared.createSessionKeyPair()
            let (passwordSeed, encryptionKey, sharedSeed, signingKeyPair) = try createTeamSessionKeys(browserPubKey: browserKeyPair.pubKey)
            let user = TeamUser(pubkey: signingKeyPair.pubKey.base64, key: sharedSeed.base64, created: Date.now, userSyncPubkey: try Seed.publicKey(), isAdmin: true, name: "devices.admin".localized)
            let role = TeamRole(id: try Crypto.shared.generateRandomId(), name: "Admins", admins: true, users: [signingKeyPair.pubKey.base64])
            let teamData: [String: Any] = [
                "organisationKey": orgKey.base64
            ]
            let message: [String: Any] = [
                "name": name,
                "data": try Crypto.shared.encryptSymmetric(JSONSerialization.data(withJSONObject: teamData, options: []), secretKey: teamEncryptionKey).base64,
                "roleId": role.id,
                "userPubkey": user.pubkey!,
                "userSyncPubkey": user.userSyncPubkey,
                "roleData": try role.encrypt(key: teamEncryptionKey),
                "userData": try user.encrypt(key: teamEncryptionKey),
                "seed": (try Crypto.shared.encrypt(teamSeed, key: encryptionKey)).base64,
                "orgPubKey": orgKeyPair.pubKey.base64
            ]
            let finalMessage: [String: Any] = [
                "teamPubKey": teamKeyPair.pubKey.base64,
                "signedMessage":try Crypto.shared.sign(message: JSONSerialization.data(withJSONObject: message, options: []), privKey: teamKeyPair.privKey).base64
            ]
            return firstly {
                API.shared.signedRequest(method: .post, message: finalMessage, path: "organisations/\(orderKeyPair.pubKey.base64)", privKey: orderKeyPair.privKey, body: nil, parameters: nil)
            }.then { _ in
                try self.createTeamSession(sharedSeed: sharedSeed, browserKeyPair: browserKeyPair, signingKeyPair: signingKeyPair, encryptionKey: encryptionKey, passwordSeed: passwordSeed, name: name, organisationKey: orgKey)
            }.map { session in
                BrowserSession.updateAllSessionData(organisationKey: orgKey, organisationType: .team, isAdmin: true)
                return (session, teamSeed.base64)
            }
        } catch {
            Logger.shared.error("errors.creating_team".localized, error: error)
            return Promise(error: error)
        }
    }

    static func restore(teamSeed64: String, organisationKey64: String) -> Promise<Session> {
        do {
            let teamSeed = try Crypto.shared.convertFromBase64(from: teamSeed64)

            // Create admin user
            let browserKeyPair = try Crypto.shared.createSessionKeyPair()
            let (passwordSeed, encryptionKey, sharedSeed, signingKeyPair) = try createTeamSessionKeys(browserPubKey: browserKeyPair.pubKey)
            let user = TeamUser(pubkey: signingKeyPair.pubKey.base64, key: sharedSeed.base64, created: Date.now, userSyncPubkey: try Seed.publicKey(), isAdmin: true, name: "devices.admin".localized)
            let encryptedSeed = (try Crypto.shared.encrypt(teamSeed, key: encryptionKey)).base64
            let organisationKey = try Crypto.shared.convertFromBase64(from: organisationKey64)
            return firstly {
                get(seed: teamSeed)
            }.then { team in
                team.restore(user: user, seed: encryptedSeed).map { ($0, team.name) }
            }.then { (_, name) -> Promise<Session> in
                try self.createTeamSession(sharedSeed: sharedSeed, browserKeyPair: browserKeyPair, signingKeyPair: signingKeyPair, encryptionKey: encryptionKey, passwordSeed: passwordSeed, name: name, organisationKey: organisationKey)
            }
        } catch {
            Logger.shared.error("errors.restoring_team".localized, error: error)
            return Promise(error: error)
        }

    }

    static func get(seed teamSeed: Data) -> Promise<Team> {
        do {
            let (teamEncryptionKey, teamKeyPair, teamPasswordSeed) = try createTeamSeeds(seed: teamSeed)
            return firstly {
                API.shared.signedRequest(method: .get, message: nil, path: "teams/\(teamKeyPair.pubKey.base64)", privKey: teamKeyPair.privKey, body: nil, parameters: nil)
            }.map {
                try Team(teamData: $0, encryptionKey: teamEncryptionKey, passwordSeed: teamPasswordSeed, keyPair: teamKeyPair)
            }
        } catch {
            return Promise(error: error)
        }
    }

    init(teamData: JSONObject, encryptionKey: Data, passwordSeed: Data, keyPair: KeyPair) throws {
        guard let accountData = teamData["accounts"] as? [String: String], let roleData = teamData["roles"] as? [String: String], let userData = teamData["users"] as? [String: [String: Any]] else {
            throw CodingError.missingData
        }
        name = teamData["name"] as? String ?? "devices.unknown".localized
        roles = Set(try roleData.compactMap { (_, role) -> TeamRole? in
            let roleData = try Crypto.shared.convertFromBase64(from: role)
            return try JSONDecoder().decode(TeamRole.self, from: Crypto.shared.decryptSymmetric(roleData, secretKey: encryptionKey))
        })
        users = Set(try userData.compactMap { (pk, user) -> TeamUser? in
            guard let data = (user["data"] as? String)?.fromBase64 else {
                throw CodingError.missingData
            }
            var user = try JSONDecoder().decode(TeamUser.self, from: Crypto.shared.decryptSymmetric(data, secretKey: encryptionKey))
            user.pubkey = pk
            return user
        })
        accounts = Set(try accountData.compactMap { (_, account) -> TeamAccount? in
            let data = try Crypto.shared.convertFromBase64(from: account)
            return try JSONDecoder().decode(TeamAccount.self, from: Crypto.shared.decryptSymmetric(data, secretKey: encryptionKey))
        })
        self.encryptionKey = encryptionKey
        self.passwordSeed = passwordSeed
        self.keyPair = keyPair
    }


    func usersForAccount(account: TeamAccount) throws -> [[String:Any]] {
        let roleUsers = Set(self.roles.filter({ account.roles.contains($0.id) }).flatMap({ $0.users }))
        let pubkeys = roleUsers.union(account.users)
        let users = self.users.filter({ pubkeys.contains($0.pubkey )})
        return try users.map({[
            "id": account.id,
            "pubKey": $0.pubkey as Any,
            "data": try $0.encryptAccount(account: account, teamPasswordSeed: passwordSeed),
            "userSyncPubkey": $0.userSyncPubkey
        ]})
    }

    func restore(user: TeamUser, seed: String) -> Promise<Void> {
        do {
            guard let role = roles.first(where: { $0.admins }) else {
                throw CodingError.missingData
            }
            let accounts = try self.accounts.filter() { $0.roles.contains(role.id) }.map {
                [
                    "id": $0.id,
                    "data": try user.encryptAccount(account: $0, teamPasswordSeed: passwordSeed)
                ]
            }
            return when(fulfilled: updateRole(role: role, pubkey: user.pubkey), try createAdminUser(user: user, seed: seed, accounts: accounts)).asVoid()
        } catch {
            return Promise(error: error)
        }
    }

    func deleteAccount(id: String) -> Promise<Void> {
        return firstly {
            API.shared.signedRequest(method: .delete, message: ["id": id], path: "teams/\(keyPair.pubKey.base64)/accounts/\(id)", privKey: keyPair.privKey, body: nil, parameters: nil)
        }.asVoid()
    }

    // MARK: - Private methods

    private func createAdminUser(user: TeamUser, seed: String, accounts: [[String: String]]) throws -> Promise<JSONObject> {
        let message: [String: Any] = [
            "httpMethod": APIMethod.post.rawValue,
            "timestamp": String(Int(Date().timeIntervalSince1970)),
            "userpubkey": user.pubkey!,
            "data": try user.encrypt(key: encryptionKey),
            "userSyncPubkey": user.userSyncPubkey,
            "accounts": accounts,
            "teamSeed": seed
        ]
        let jsonData = try JSONSerialization.data(withJSONObject: message, options: [])
        let signature = try Crypto.shared.signature(message: jsonData, privKey: keyPair.privKey).base64
        return API.shared.request(path: "teams/\(keyPair.pubKey.base64)/users/\(user.pubkey!)", parameters: nil, method: .post, signature: signature, body: jsonData)
    }

    private func updateRole(role: TeamRole, pubkey: String) -> Promise<JSONObject> {
        do {
            var adminRole = role
            adminRole.users.append(pubkey)
            let roleMessage = [
                "id": adminRole.id,
                "data": try adminRole.encrypt(key: encryptionKey)
            ]
            return API.shared.signedRequest(method: .put, message: roleMessage, path: "teams/\(keyPair.pubKey.base64)/roles/\(adminRole.id)", privKey: keyPair.privKey, body: nil, parameters: nil)
        } catch {
            return Promise(error: error)
        }
    }

    // MARK: - Private static functions

    private static func createTeamSessionKeys(browserPubKey: Data) throws -> (Data, Data, Data, KeyPair) {
        let keyPairForSharedKey = try Crypto.shared.createSessionKeyPair()
        let sharedSeed = try Crypto.shared.generateSharedKey(pubKey: browserPubKey, privKey: keyPairForSharedKey.privKey)
        let (passwordSeed, encryptionKey, signingKeyPair) = try TeamSession.createTeamSessionKeys(seed: sharedSeed)
        return (passwordSeed, encryptionKey, sharedSeed, signingKeyPair)
    }

    private static func createTeamSeeds(seed: Data) throws -> (Data, KeyPair, Data) {
        let teamPasswordSeed = try Crypto.shared.deriveKey(keyData: seed, context: TEAM_SEED_CONTEXT, index: 0)
        let teamBackupKey = try Crypto.shared.deriveKey(keyData: seed, context: TEAM_SEED_CONTEXT, index: 1)
        let teamEncryptionKey = try Crypto.shared.deriveKey(keyData: teamBackupKey, context: TEAM_SEED_CONTEXT, index: 0)
        let teamKeyPair = try Crypto.shared.createSigningKeyPair(seed: teamBackupKey)
        return (teamEncryptionKey, teamKeyPair, teamPasswordSeed)
    }

    private static func createTeamSession(sharedSeed: Data, browserKeyPair: KeyPair, signingKeyPair: KeyPair, encryptionKey: Data, passwordSeed: Data, name: String, organisationKey: Data) throws -> Promise<Session> {
        do {
            let session = TeamSession(id: browserKeyPair.pubKey.base64.hash, signingPubKey: signingKeyPair.pubKey, title: "\("devices.admin".localized) @ \(name)", version: 2, isAdmin: true, created: true, lastChange: Date.now, organisationKey: organisationKey)
            try session.save(sharedSeed: sharedSeed, key: encryptionKey, signingKeyPair: signingKeyPair, passwordSeed: passwordSeed)
            TeamSession.count += 1
            return session.backup().map { session }
        } catch is KeychainError {
            throw SessionError.exists
        } catch is CryptoError {
            throw SessionError.invalid
        }
    }

}
