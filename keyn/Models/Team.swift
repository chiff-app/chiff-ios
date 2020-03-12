//
//  Team.swift
//  keyn
//
//  Created by Bas Doorn on 07/02/2020.
//  Copyright © 2020 keyn. All rights reserved.
//

import Foundation

struct Team {

    let roles: [TeamRole]
    let users: [TeamUser]
    let name: String
    let key: Data
    let keyPair: KeyPair

    static let CRYPTO_CONTEXT = "keynteam"
    static let TEAM_SEED_CONTEXT = "teamseed"

    static func create(token: String, name: String, completionHandler: @escaping (Result<Session, Error>) -> Void) {
        do {
            // Generate team seed
            let teamSeed = try Crypto.shared.generateSeed(length: 32)
            let (teamEncryptionKey, teamKeyPair) = try createTeamSeeds(seed: teamSeed)

            // Create admin user
            let browserKeyPair = try Crypto.shared.createSessionKeyPair()
            let (passwordSeed, encryptionKey, sharedSeed, signingKeyPair) = try createTeamSessionKeys(browserPubKey: browserKeyPair.pubKey)
            guard let endpoint = Properties.endpoint else {
                throw SessionError.noEndpoint
            }
            let user = TeamUser(pubkey: signingKeyPair.pubKey.base64, key: sharedSeed.base64, created: Date.now, arn: endpoint, isAdmin: true, name: "devices.admin".localized)
            let role = TeamRole(id: try Crypto.shared.generateRandomId(), name: "Admins", admins: true, users: [signingKeyPair.pubKey.base64])
            let message = [
                "name": name,
                "token": token,
                "roleId": role.id,
                "userPubkey": user.pubkey,
                "arn": user.arn,
                "roleData": try role.encrypt(key: teamEncryptionKey),
                "userData": try user.encrypt(key: teamEncryptionKey),
                "seed": (try Crypto.shared.encrypt(teamSeed, key: encryptionKey)).base64
            ]
            API.shared.signedRequest(method: .post, message: message, path: "teams/\(teamKeyPair.pubKey.base64)", privKey: teamKeyPair.privKey, body: nil) { (result) in
                if case .failure(let error) = result {
                    completionHandler(.failure(error))
                } else {
                    self.createTeamSession(browserKeyPair: browserKeyPair, signingKeyPair: signingKeyPair, encryptionKey: encryptionKey, seed: passwordSeed, name: name, completionHandler: completionHandler)
                }

            }
        } catch {
            Logger.shared.error("errors.creating_team".localized, error: error)
            completionHandler(.failure(error))
        }
    }

    static func restore(teamSeed64: String, completionHandler: @escaping (Result<Session, Error>) -> Void) {
        do {
            let teamSeed = try Crypto.shared.convertFromBase64(from: teamSeed64)

            // Create admin user
            let browserKeyPair = try Crypto.shared.createSessionKeyPair()
            let (passwordSeed, encryptionKey, sharedSeed, signingKeyPair) = try createTeamSessionKeys(browserPubKey: browserKeyPair.pubKey)
            guard let endpoint = Properties.endpoint else {
                throw SessionError.noEndpoint
            }
            let user = TeamUser(pubkey: signingKeyPair.pubKey.base64, key: sharedSeed.base64, created: Date.now, arn: endpoint, isAdmin: true, name: "devices.admin".localized)
            get(seed: teamSeed) { (result) in
                do {
                    let team = try result.get()
                    let group = DispatchGroup()
                    var groupError: Error? = nil
                    group.enter()
                    team.updateRole(pubkey: user.pubkey) { result in
                        if case .failure(let error) = result {
                            groupError = error
                        }
                        group.leave()
                    }
                    team.createAdminUser(user: user, seed: (try Crypto.shared.encrypt(teamSeed, key: encryptionKey)).base64)  { result in
                        if case .failure(let error) = result {
                            groupError = error
                        }
                        group.leave()
                    }
                    group.notify(queue: .main) {
                        if let error = groupError {
                            completionHandler(.failure(error))
                        } else {
                            self.createTeamSession(browserKeyPair: browserKeyPair, signingKeyPair: signingKeyPair, encryptionKey: encryptionKey, seed: passwordSeed, name: team.name, completionHandler: completionHandler)
                        }
                    }
                } catch is KeychainError {
                    completionHandler(.failure(SessionError.exists))
                } catch is CryptoError {
                    completionHandler(.failure(SessionError.invalid))
                } catch {
                    completionHandler(.failure(error))
                }
            }
        } catch {
            Logger.shared.error("errors.restoring_team".localized, error: error)
            completionHandler(.failure(error))
        }

    }

    static func get(seed teamSeed: Data, completionHandler: @escaping (Result<Team, Error>) -> Void) {
        do {
            let (teamEncryptionKey, teamKeyPair) = try createTeamSeeds(seed: teamSeed)
            API.shared.signedRequest(method: .get, message: nil, path: "teams/\(teamKeyPair.pubKey.base64)", privKey: teamKeyPair.privKey, body: nil) { (result) in
                do {
                    let team = try Team(teamData: result.get(), key: teamEncryptionKey, keyPair: teamKeyPair)
                    completionHandler(.success(team))
                } catch {
                    completionHandler(.failure(error))
                }
            }
        } catch {
            completionHandler(.failure(error))
        }
    }

    init(teamData: JSONObject, key: Data, keyPair: KeyPair) throws {
        guard let roleData = teamData["roles"] as? [String: String], let userData = teamData["users"] as? [String: String] else {
            throw CodingError.missingData
        }
        name = teamData["name"] as? String ?? "devices.unknown".localized
        roles = try roleData.compactMap { (_, role) -> TeamRole? in
            let roleData = try Crypto.shared.convertFromBase64(from: role)
            return try JSONDecoder().decode(TeamRole.self, from: Crypto.shared.decryptSymmetric(roleData, secretKey: key))
        }
        users = try userData.compactMap { (_, user) -> TeamUser? in
            let userData = try Crypto.shared.convertFromBase64(from: user)
            return try JSONDecoder().decode(TeamUser.self, from: Crypto.shared.decryptSymmetric(userData, secretKey: key))
        }
        self.key = key
        self.keyPair = keyPair
    }

    func updateRole(pubkey: String, completionHandler: @escaping (Result<JSONObject, Error>) -> Void) {
        do {
            guard var adminRole = roles.first(where: { $0.admins }) else {
                throw CodingError.missingData
            }
            adminRole.users.append(pubkey)
            let roleMessage = [
                "id": adminRole.id,
                "data": try adminRole.encrypt(key: key)
            ]
            API.shared.signedRequest(method: .put, message: roleMessage, path: "teams/\(keyPair.pubKey.base64)/roles/\(adminRole.id)", privKey: keyPair.privKey, body: nil, completionHandler: completionHandler)
        } catch {
            completionHandler(.failure(error))
        }
    }

    func createAdminUser(user: TeamUser, seed: String, completionHandler: @escaping (Result<JSONObject, Error>) -> Void) {
        do {
            let message: [String: Any] = [
                "userpubkey": user.pubkey,
                "data": try user.encrypt(key: key),
                "arn": user.arn,
                "accounts": [],
                "teamSeed": seed
            ]
            API.shared.signedRequest(method: .post, message: message, path: "teams/\(keyPair.pubKey.base64)/users/\(user.pubkey)", privKey: keyPair.privKey, body: nil, completionHandler: completionHandler)
        } catch {
            completionHandler(.failure(error))
        }
    }

    // MARK: - Private static functions

    private static func createTeamSessionKeys(browserPubKey: Data) throws -> (Data, Data, Data, KeyPair) {
        let keyPairForSharedKey = try Crypto.shared.createSessionKeyPair()
        let sharedSeed = try Crypto.shared.generateSharedKey(pubKey: browserPubKey, privKey: keyPairForSharedKey.privKey)
        let (passwordSeed, encryptionKey, signingKeyPair) = try TeamSession.createTeamSessionKeys(seed: sharedSeed)
        return (passwordSeed, encryptionKey, sharedSeed, signingKeyPair)
    }

    private static func createTeamSeeds(seed: Data) throws -> (Data, KeyPair) {
        let teamBackupKey = try Crypto.shared.deriveKey(keyData: seed, context: TEAM_SEED_CONTEXT, index: 1)
        let teamEncryptionKey = try Crypto.shared.deriveKey(keyData: teamBackupKey, context: TEAM_SEED_CONTEXT, index: 0)
        let teamKeyPair = try Crypto.shared.createSigningKeyPair(seed: teamBackupKey)
        return (teamEncryptionKey, teamKeyPair)
    }


    private static func createTeamSession(browserKeyPair: KeyPair, signingKeyPair: KeyPair, encryptionKey: Data, seed: Data, name: String, completionHandler: @escaping (Result<Session, Error>) -> Void) {
        do {
            let session = TeamSession(id: browserKeyPair.pubKey.base64.hash, signingPubKey: signingKeyPair.pubKey, title: "\("devices.admin".localized) @ \(name)", version: 2, isAdmin: true, created: true)
            try session.save(key: encryptionKey, signingKeyPair: signingKeyPair, passwordSeed: seed)
            TeamSession.count += 1
            completionHandler(.success(session))
        } catch is KeychainError {
            completionHandler(.failure(SessionError.exists))
        } catch is CryptoError {
            completionHandler(.failure(SessionError.invalid))
        } catch {
            completionHandler(.failure(error))
        }
    }

}
