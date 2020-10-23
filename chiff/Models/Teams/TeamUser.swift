//
//  TeamUser.swift
//  keyn
//
//  Created by Bas Doorn on 17/03/2020.
//  Copyright © 2020 keyn. All rights reserved.
//

import Foundation

struct TeamUser: Codable, AccessControllable {
    var pubkey: String!
    let userPubkey: String
    let id: String
    let key: String
    let created: Timestamp
    let userSyncPubkey: String
    let isAdmin: Bool
    let name: String

    static let cryptoContext = "keynteam"

    func encrypt(key: Data) throws -> String {
        let data = try JSONEncoder().encode(self)
        let ciphertext = try Crypto.shared.encryptSymmetric(data, secretKey: key)
        return try Crypto.shared.convertToBase64(from: ciphertext)
    }

    func encryptAccount(account: TeamAccount, teamPasswordSeed: Data) throws -> String {
        guard let site = account.sites.first else {
            throw CodingError.missingData
        }
        guard let key = key.fromBase64 else {
            throw CodingError.stringDecoding
        }
        let passwordSeed = try Crypto.shared.deriveKey(keyData: key, context: TeamUser.cryptoContext, index: 0)
        let encryptionKey = try Crypto.shared.deriveKey(keyData: key, context: TeamUser.cryptoContext, index: 1)
        let generator = PasswordGenerator(username: account.username, siteId: site.id, ppd: site.ppd, passwordSeed: passwordSeed)
        let offset = try generator.calculateOffset(index: 0, password: account.password(for: teamPasswordSeed))
        let backupAccount = BackupSharedAccount(id: account.id,
                                                username: account.username,
                                                sites: account.sites,
                                                passwordIndex: 0,
                                                passwordOffset: offset,
                                                tokenURL: account.tokenURL,
                                                tokenSecret: account.tokenSecret,
                                                version: account.version)
        let data = try JSONEncoder().encode(backupAccount)
        return try Crypto.shared.encrypt(data, key: encryptionKey).base64
    }
}

extension TeamUser: Hashable {

    static func == (lhs: TeamUser, rhs: TeamUser) -> Bool {
        return lhs.pubkey == rhs.pubkey
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(pubkey)
    }

}
