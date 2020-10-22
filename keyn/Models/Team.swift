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

    let id: String
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
            let teamId = try Crypto.shared.generateSeed(length: 32).base64
            let (teamEncryptionKey, teamKeyPair, _) = try createTeamSeeds(seed: teamSeed)
            let orgKey = try Crypto.shared.generateSeed(length: 32) // This key is shared with all team users to retrieve organisational info like PPDs
            let orgKeyPair = try Crypto.shared.createSigningKeyPair(seed: orgKey)

            // Create admin user
            let browserKeyPair = try Crypto.shared.createSessionKeyPair()
            let (passwordSeed, encryptionKey, sharedSeed, signingKeyPair, keyPairForSharedKey) = try createTeamSessionKeys(browserPubKey: browserKeyPair.pubKey)
            let user = TeamUser(pubkey: signingKeyPair.pubKey.base64, userPubkey: keyPairForSharedKey.pubKey.base64, id: browserKeyPair.pubKey.base64.hash, key: sharedSeed.base64, created: Date.now, userSyncPubkey: try Seed.publicKey(), isAdmin: true, name: "devices.admin".localized)
            let role = TeamRole(id: try Crypto.shared.generateRandomId(), name: "Admins", admins: true, users: [user.id])
            let teamData: [String: Any] = [
                "organisationKey": orgKey.base64
            ]
            let message: [String: Any] = [
                "name": name,
                "id": teamId,
                "data": try Crypto.shared.encryptSymmetric(JSONSerialization.data(withJSONObject: teamData, options: []), secretKey: teamEncryptionKey).base64,
                "roleId": role.id,
                "userPubkey": user.pubkey!,
                "userId": user.id,
                "userSyncPubkey": user.userSyncPubkey,
                "roleData": try role.encrypt(key: teamEncryptionKey),
                "userData": try user.encrypt(key: teamEncryptionKey),
                "seed": (try Crypto.shared.encrypt(teamSeed, key: encryptionKey)).base64,
                "orgPubKey": orgKeyPair.pubKey.base64
            ]
            let finalMessage: [String: Any] = [
                "teamPubKey": teamKeyPair.pubKey.base64,
                "signedMessage": try Crypto.shared.sign(message: JSONSerialization.data(withJSONObject: message, options: []), privKey: teamKeyPair.privKey).base64
            ]
            return firstly {
                API.shared.signedRequest(method: .post, message: finalMessage, path: "organisations/\(orderKeyPair.pubKey.base64)", privKey: orderKeyPair.privKey, body: nil, parameters: nil)
            }.then { _ in
                try self.createTeamSession(id: teamId, sharedSeed: sharedSeed, browserKeyPair: browserKeyPair, signingKeyPair: signingKeyPair, encryptionKey: encryptionKey, passwordSeed: passwordSeed, name: name, organisationKey: orgKey, sharedKeyKeyPair: keyPairForSharedKey)
            }.map { session in
                BrowserSession.updateAllSessionData(organisationKey: orgKey, organisationType: .team, isAdmin: true)
                return (session, teamSeed.base64)
            }
        } catch {
            Logger.shared.error("errors.creating_team".localized, error: error)
            return Promise(error: error)
        }
    }

    static func get(id: String, seed teamSeed: Data) -> Promise<Team> {
        do {
            let (teamEncryptionKey, teamKeyPair, teamPasswordSeed) = try createTeamSeeds(seed: teamSeed)
            return firstly {
                API.shared.signedRequest(method: .get, message: nil, path: "teams/\(id)", privKey: teamKeyPair.privKey, body: nil, parameters: nil)
            }.map {
                try Team(id: id, teamData: $0, encryptionKey: teamEncryptionKey, passwordSeed: teamPasswordSeed, keyPair: teamKeyPair)
            }
        } catch {
            return Promise(error: error)
        }
    }

    init(id: String, teamData: JSONObject, encryptionKey: Data, passwordSeed: Data, keyPair: KeyPair) throws {
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
        self.id = id
        self.encryptionKey = encryptionKey
        self.passwordSeed = passwordSeed
        self.keyPair = keyPair
    }

    func usersForAccount(account: TeamAccount) throws -> [[String: Any]] {
        let roleUsers = Set(self.roles.filter({ account.roles.contains($0.id) }).flatMap({ $0.users }))
        let ids = roleUsers.union(account.users)
        let users = self.users.filter({ ids.contains($0.id )})
        return try users.map({[
            "id": $0.id,
            "pubKey": $0.pubkey as Any,
            "data": try $0.encryptAccount(account: account, teamPasswordSeed: passwordSeed),
            "userSyncPubkey": $0.userSyncPubkey
        ]})
    }

    func deleteAccount(id: String) -> Promise<Void> {
        return firstly {
            API.shared.signedRequest(method: .delete, message: ["id": id], path: "teams/\(self.id)/accounts/\(id)", privKey: keyPair.privKey, body: nil, parameters: nil)
        }.asVoid()
    }

    // MARK: - Private static functions

    private static func createTeamSessionKeys(browserPubKey: Data) throws -> (Data, Data, Data, KeyPair, KeyPair) {
        let keyPairForSharedKey = try Crypto.shared.createSessionKeyPair()
        let sharedSeed = try Crypto.shared.generateSharedKey(pubKey: browserPubKey, privKey: keyPairForSharedKey.privKey)
        let (passwordSeed, encryptionKey, signingKeyPair) = try TeamSession.createTeamSessionKeys(seed: sharedSeed)
        return (passwordSeed, encryptionKey, sharedSeed, signingKeyPair, keyPairForSharedKey)
    }

    private static func createTeamSeeds(seed: Data) throws -> (Data, KeyPair, Data) {
        let teamPasswordSeed = try Crypto.shared.deriveKey(keyData: seed, context: TEAM_SEED_CONTEXT, index: 0)
        let teamBackupKey = try Crypto.shared.deriveKey(keyData: seed, context: TEAM_SEED_CONTEXT, index: 1)
        let teamEncryptionKey = try Crypto.shared.deriveKey(keyData: teamBackupKey, context: TEAM_SEED_CONTEXT, index: 0)
        let teamKeyPair = try Crypto.shared.createSigningKeyPair(seed: teamBackupKey)
        return (teamEncryptionKey, teamKeyPair, teamPasswordSeed)
    }

    private static func createTeamSession(id: String, sharedSeed: Data, browserKeyPair: KeyPair, signingKeyPair: KeyPair, encryptionKey: Data, passwordSeed: Data, name: String, organisationKey: Data, sharedKeyKeyPair: KeyPair) throws -> Promise<Session> {
        do {
            let session = TeamSession(id: browserKeyPair.pubKey.base64.hash, teamId: id, signingPubKey: signingKeyPair.pubKey, title: "\("devices.admin".localized) @ \(name)", version: 2, isAdmin: true, created: true, lastChange: Date.now, organisationKey: organisationKey)
            try session.save(sharedSeed: sharedSeed, key: encryptionKey, signingKeyPair: signingKeyPair, passwordSeed: passwordSeed, sharedKeyPrivKey: sharedKeyKeyPair.privKey)
            TeamSession.count += 1
            return session.backup().map { session }
        } catch is KeychainError {
            throw SessionError.exists
        } catch is CryptoError {
            throw SessionError.invalid
        }
    }

}
