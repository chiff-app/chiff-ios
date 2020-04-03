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
    let name: String
    let encryptionKey: Data
    let passwordSeed: Data
    let keyPair: KeyPair

    static let CRYPTO_CONTEXT = "keynteam"
    static let TEAM_SEED_CONTEXT = "teamseed"

    static func create(token: String, name: String) -> Promise<Session> {
        do {
            // Generate team seed
            let teamSeed = try Crypto.shared.generateSeed(length: 32)
            let (teamEncryptionKey, teamKeyPair, _) = try createTeamSeeds(seed: teamSeed)

            // Create admin user
            let browserKeyPair = try Crypto.shared.createSessionKeyPair()
            let (passwordSeed, encryptionKey, sharedSeed, signingKeyPair) = try createTeamSessionKeys(browserPubKey: browserKeyPair.pubKey)
            guard let endpoint = Properties.endpoint else {
                throw SessionError.noEndpoint
            }
            let user = TeamUser(pubkey: signingKeyPair.pubKey.base64, key: sharedSeed.base64, created: Date.now, arn: endpoint, isAdmin: true, name: "devices.admin".localized)
            let role = TeamRole(id: try Crypto.shared.generateRandomId(), name: "Admins", admins: true, users: [signingKeyPair.pubKey.base64])
            let message: [String: Any] = [
                "name": name,
                "token": token,
                "roleId": role.id,
                "userPubkey": user.pubkey!,
                "arn": user.arn,
                "roleData": try role.encrypt(key: teamEncryptionKey),
                "userData": try user.encrypt(key: teamEncryptionKey),
                "seed": (try Crypto.shared.encrypt(teamSeed, key: encryptionKey)).base64
            ]
            return firstly {
                API.shared.signedRequest(method: .post, message: message, path: "teams/\(teamKeyPair.pubKey.base64)", privKey: teamKeyPair.privKey, body: nil)
            }.map { _ in
                try self.createTeamSession(browserKeyPair: browserKeyPair, signingKeyPair: signingKeyPair, encryptionKey: encryptionKey, seed: passwordSeed, name: name)
            }
        } catch {
            Logger.shared.error("errors.creating_team".localized, error: error)
            return Promise(error: error)
        }
    }

    static func restore(teamSeed64: String) -> Promise<Session> {
        do {
            let teamSeed = try Crypto.shared.convertFromBase64(from: teamSeed64)

            // Create admin user
            let browserKeyPair = try Crypto.shared.createSessionKeyPair()
            let (passwordSeed, encryptionKey, sharedSeed, signingKeyPair) = try createTeamSessionKeys(browserPubKey: browserKeyPair.pubKey)
            guard let endpoint = Properties.endpoint else {
                throw SessionError.noEndpoint
            }
            let user = TeamUser(pubkey: signingKeyPair.pubKey.base64, key: sharedSeed.base64, created: Date.now, arn: endpoint, isAdmin: true, name: "devices.admin".localized)
            let encryptedSeed = (try Crypto.shared.encrypt(teamSeed, key: encryptionKey)).base64
            return firstly {
                get(seed: teamSeed)
            }.then { team in
                when(fulfilled: team.updateRole(pubkey: user.pubkey), team.createAdminUser(user: user, seed: encryptedSeed)).map({ ($0, team.name) })
            }.map { _, name in
                try self.createTeamSession(browserKeyPair: browserKeyPair, signingKeyPair: signingKeyPair, encryptionKey: encryptionKey, seed: passwordSeed, name: name)
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
                API.shared.signedRequest(method: .get, message: nil, path: "teams/\(teamKeyPair.pubKey.base64)", privKey: teamKeyPair.privKey, body: nil)
            }.map {
                try Team(teamData: $0, encryptionKey: teamEncryptionKey, passwordSeed: teamPasswordSeed, keyPair: teamKeyPair)
            }
        } catch {
            return Promise(error: error)
        }
    }

    init(teamData: JSONObject, encryptionKey: Data, passwordSeed: Data, keyPair: KeyPair) throws {
        guard let roleData = teamData["roles"] as? [String: String], let userData = teamData["users"] as? [String: [String: Any]] else {
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
        self.encryptionKey = encryptionKey
        self.passwordSeed = passwordSeed
        self.keyPair = keyPair
    }

    func usersForAccount(account: TeamAccount) throws -> [[String:String]] {
        let roleUsers = Set(self.roles.filter({ account.roles.contains($0.id) }).flatMap({ $0.users }))
        let pubkeys = roleUsers.union(account.users)
        let users = self.users.filter({ pubkeys.contains($0.pubkey )})
        return try users.map({[
            "id": account.id,
            "pubKey": $0.pubkey,
            "data": try $0.encryptAccount(account: account),
            "arn": $0.arn
        ]})
    }

    func updateRole(pubkey: String) -> Promise<JSONObject> {
        do {
            guard var adminRole = roles.first(where: { $0.admins }) else {
                throw CodingError.missingData
            }
            adminRole.users.append(pubkey)
            let roleMessage = [
                "id": adminRole.id,
                "data": try adminRole.encrypt(key: encryptionKey)
            ]
            return API.shared.signedRequest(method: .put, message: roleMessage, path: "teams/\(keyPair.pubKey.base64)/roles/\(adminRole.id)", privKey: keyPair.privKey, body: nil)
        } catch {
            return Promise(error: error)
        }
    }

    func createAdminUser(user: TeamUser, seed: String) -> Promise<JSONObject> {
        do {
            let message: [String: Any] = [
                "userpubkey": user.pubkey!,
                "data": try user.encrypt(key: encryptionKey),
                "arn": user.arn,
                "accounts": [],
                "teamSeed": seed
            ]
            return API.shared.signedRequest(method: .post, message: message, path: "teams/\(keyPair.pubKey.base64)/users/\(user.pubkey!)", privKey: keyPair.privKey, body: nil)
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


    private static func createTeamSession(browserKeyPair: KeyPair, signingKeyPair: KeyPair, encryptionKey: Data, seed: Data, name: String) throws -> Session {
        do {
            let session = TeamSession(id: browserKeyPair.pubKey.base64.hash, signingPubKey: signingKeyPair.pubKey, title: "\("devices.admin".localized) @ \(name)", version: 2, isAdmin: true, created: true)
            try session.save(key: encryptionKey, signingKeyPair: signingKeyPair, passwordSeed: seed)
            TeamSession.count += 1
            return session
        } catch is KeychainError {
            throw SessionError.exists
        } catch is CryptoError {
            throw SessionError.invalid
        }
    }

}
