//
//  Team.swift
//  keyn
//
//  Created by Bas Doorn on 07/02/2020.
//  Copyright © 2020 keyn. All rights reserved.
//

import Foundation

class Team {

    let CRYPTO_CONTEXT = "keynteam"
    let TEAM_SEED_CONTEXT = "teamseed"
    let group = DispatchGroup()
    var groupError: Error?

    func create(token: String, name: String, completionHandler: @escaping (Result<Session, Error>) -> Void) {
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
            let user = TeamAdminUser(pubkey: signingKeyPair.pubKey.base64, key: sharedSeed.base64, created: Date.now, arn: endpoint)
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
            Logger.shared.error("Error creating team", error: error)
            completionHandler(.failure(error))
        }
    }

    func restore(teamSeed64: String, completionHandler: @escaping (Result<Session, Error>) -> Void) {
        do {
            let teamSeed = try Crypto.shared.convertFromBase64(from: teamSeed64)
            let (teamEncryptionKey, teamKeyPair) = try createTeamSeeds(seed: teamSeed)

            // Create admin user
            let browserKeyPair = try Crypto.shared.createSessionKeyPair()
            let (passwordSeed, encryptionKey, sharedSeed, signingKeyPair) = try createTeamSessionKeys(browserPubKey: browserKeyPair.pubKey)
            guard let endpoint = Properties.endpoint else {
                throw SessionError.noEndpoint
            }
            let user = TeamAdminUser(pubkey: signingKeyPair.pubKey.base64, key: sharedSeed.base64, created: Date.now, arn: endpoint)
            API.shared.signedRequest(method: .get, message: nil, path: "teams/\(teamKeyPair.pubKey.base64)", privKey: teamKeyPair.privKey, body: nil) { (result) in
                do {
                    let teamData = try result.get()
                    guard let roleData = teamData["roles"] as? [String: String] else {
                        throw CodingError.missingData
                    }
                    let name = teamData["name"] as? String ?? "unknown"
                    
                    self.updateRole(roleData: roleData, key: teamEncryptionKey, keyPair: teamKeyPair, pubkey: user.pubkey)
                    self.createAdminUser(user: user, seed: (try Crypto.shared.encrypt(teamSeed, key: encryptionKey)).base64, key: teamEncryptionKey, keyPair: teamKeyPair)
                    self.group.notify(queue: .main) {
                        self.createTeamSession(browserKeyPair: browserKeyPair, signingKeyPair: signingKeyPair, encryptionKey: encryptionKey, seed: passwordSeed, name: name, completionHandler: completionHandler)
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
            Logger.shared.error("Error restoring team", error: error)
            completionHandler(.failure(error))
        }

    }

    private func createTeamSessionKeys(browserPubKey: Data) throws -> (Data, Data, Data, KeyPair) {
        let keyPairForSharedKey = try Crypto.shared.createSessionKeyPair()
        let sharedSeed = try Crypto.shared.generateSharedKey(pubKey: browserPubKey, privKey: keyPairForSharedKey.privKey)
        let passwordSeed =  try Crypto.shared.deriveKey(keyData: sharedSeed, context: CRYPTO_CONTEXT, index: 0) // Used to generate passwords
        let encryptionKey = try Crypto.shared.deriveKey(keyData: sharedSeed, context: CRYPTO_CONTEXT, index: 1) // Used to encrypt messages for this session
        let signingKeyPair = try Crypto.shared.createSigningKeyPair(seed: Crypto.shared.deriveKey(keyData: sharedSeed, context: CRYPTO_CONTEXT, index: 2)) // Used to sign messages for the server
        return (passwordSeed, encryptionKey, sharedSeed, signingKeyPair)
    }

    private func createTeamSeeds(seed: Data) throws -> (Data, KeyPair) {
        let teamBackupKey = try Crypto.shared.deriveKey(keyData: seed, context: TEAM_SEED_CONTEXT, index: 1)
        let teamEncryptionKey = try Crypto.shared.deriveKey(keyData: teamBackupKey, context: TEAM_SEED_CONTEXT, index: 0)
        let teamKeyPair = try Crypto.shared.createSigningKeyPair(seed: teamBackupKey)
        return (teamEncryptionKey, teamKeyPair)
    }

    private func updateRole(roleData: [String: String], key: Data, keyPair: KeyPair, pubkey: String) {
        do {
            self.group.enter()
            guard var adminRole = (try roleData.compactMap { (_, role) -> TeamRole? in
                let roleData = try Crypto.shared.convertFromBase64(from: role)
                return try JSONDecoder().decode(TeamRole.self, from: Crypto.shared.decryptSymmetric(roleData, secretKey: key))
            }.first(where: { $0.admins })) else {
                throw CodingError.missingData
            }
            adminRole.users.append(pubkey)
            let roleMessage = [
                "id": adminRole.id,
                "data": try adminRole.encrypt(key: key)
            ]
            API.shared.signedRequest(method: .put, message: roleMessage, path: "teams/\(keyPair.pubKey.base64)/roles/\(adminRole.id)", privKey: keyPair.privKey, body: nil) { result in
                if self.groupError == nil {
                    if case let .failure(error) = result {
                        self.groupError = error
                    }
                }
                self.group.leave()
            }
        } catch {
            self.groupError = error
        }
    }

    private func createAdminUser(user: TeamAdminUser, seed: String, key: Data, keyPair: KeyPair) {
        do {
            self.group.enter()
            let message: [String: Any] = [
                "userpubkey": user.pubkey,
                "data": try user.encrypt(key: key),
                "arn": user.arn,
                "accounts": [],
                "teamSeed": seed
            ]
            API.shared.signedRequest(method: .post, message: message, path: "teams/\(keyPair.pubKey.base64)/users/\(user.pubkey)", privKey: keyPair.privKey, body: nil) { result in
                if self.groupError == nil {
                    if case let .failure(error) = result {
                        self.groupError = error
                    }
                }
                self.group.leave()
            }
        } catch {
            self.groupError = error
        }
    }

    private func createTeamSession(browserKeyPair: KeyPair, signingKeyPair: KeyPair, encryptionKey: Data, seed: Data, name: String, completionHandler: @escaping (Result<Session, Error>) -> Void) {
        do {
            if let error = self.groupError {
                throw error
            }
            let session = TeamSession(id: browserKeyPair.pubKey.base64.hash, signingPubKey: signingKeyPair.pubKey, title: "Admin @ \(name)", version: 2, isAdmin: true)
            session.created = true
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
