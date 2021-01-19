//
//  Team.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import Foundation
import PromiseKit

enum TeamError: Error {
    case inconsistent
}

struct Team {

    let id: String
    let roles: Set<TeamRole>
    let users: Set<TeamUser>
    let accounts: Set<TeamAccount>
    let name: String
    let seed: Data
    let encryptionKey: Data
    let passwordSeed: Data
    let keyPair: KeyPair
    let teamSessionKeys: TeamSessionKeys

    static let cryptoContext = "teamseed"

    init(id: String, seed: Data, teamData: JSONObject) throws {
        self.id = id
        self.seed = seed
        let (encryptionKey, keyPair, passwordSeed) = try Self.createTeamSeeds(seed: seed)
        self.encryptionKey = encryptionKey
        self.passwordSeed = passwordSeed
        self.keyPair = keyPair
        self.teamSessionKeys = try TeamSessionKeys()

        guard let accountData = teamData["accounts"] as? [String: String], let roleData = teamData["roles"] as? [String: String], let userData = teamData["users"] as? [String: [String: Any]] else {
            throw CodingError.missingData
        }
        name = teamData["name"] as? String ?? "devices.unknown".localized
        roles = Set(try roleData.compactMap { (_, role) -> TeamRole? in
            let roleData = try Crypto.shared.convertFromBase64(from: role)
            return try JSONDecoder().decode(TeamRole.self, from: Crypto.shared.decryptSymmetric(roleData, secretKey: encryptionKey))
        })
        users = Set(try userData.compactMap { (pubkey, user) -> TeamUser? in
            guard let data = (user["data"] as? String)?.fromBase64 else {
                throw CodingError.missingData
            }
            var user = try JSONDecoder().decode(TeamUser.self, from: Crypto.shared.decryptSymmetric(data, secretKey: encryptionKey))
            user.pubkey = pubkey
            return user
        })
        accounts = Set(try accountData.compactMap { (_, account) -> TeamAccount? in
            let data = try Crypto.shared.convertFromBase64(from: account)
            return try JSONDecoder().decode(TeamAccount.self, from: Crypto.shared.decryptSymmetric(data, secretKey: encryptionKey))
        })
    }

    /// Retrieve a list of objects with accounts encrypted for each user that is allowed to see this account.
    /// - Parameter account: The team account.
    /// - Throws: Encryption or encoding errors.
    /// - Returns: A list of objects with accounts encrypted for each user that is allowed to see this account.
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

    /// Remove an account from this team.
    /// - Parameter id: The ID of the account that should be removed.
    func deleteAccount(id: String) -> Promise<Void> {
        return firstly {
            API.shared.signedRequest(path: "teams/\(self.id)/accounts/\(id)", method: .delete, privKey: keyPair.privKey, message: ["id": id])
        }.asVoid()
    }

    // MARK: - Static methods

    /// Get this team from the server.
    /// - Parameters:
    ///   - id: The team ID.
    ///   - seed: The team seed.
    /// - Returns: The team.
    static func get(id: String, seed: Data) -> Promise<Team> {
        do {
            let teamBackupKey = try Crypto.shared.deriveKey(keyData: seed, context: cryptoContext, index: 1)
            let teamKeyPair = try Crypto.shared.createSigningKeyPair(seed: teamBackupKey)
            return firstly {
                API.shared.signedRequest(path: "teams/\(id)", method: .get, privKey: teamKeyPair.privKey)
            }.map {
                try Team(id: id, seed: seed, teamData: $0)
            }
        } catch {
            return Promise(error: error)
        }
    }

    /// Derive subkeys from the team seed.
    /// - Parameter seed: The team seed.
    /// - Throws: Decryption errors.
    /// - Returns: A triple with the team encryption key, team keypair and the team password seed.
    static func createTeamSeeds(seed: Data) throws -> (Data, KeyPair, Data) {
        let teamPasswordSeed = try Crypto.shared.deriveKey(keyData: seed, context: cryptoContext, index: 0)
        let teamBackupKey = try Crypto.shared.deriveKey(keyData: seed, context: cryptoContext, index: 1)
        let teamEncryptionKey = try Crypto.shared.deriveKey(keyData: teamBackupKey, context: cryptoContext, index: 0)
        let teamKeyPair = try Crypto.shared.createSigningKeyPair(seed: teamBackupKey)
        return (teamEncryptionKey, teamKeyPair, teamPasswordSeed)
    }

}
