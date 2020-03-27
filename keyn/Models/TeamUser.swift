//
//  TeamUser.swift
//  keyn
//
//  Created by Bas Doorn on 17/03/2020.
//  Copyright © 2020 keyn. All rights reserved.
//

import Foundation

struct TeamUser: Codable {
    var pubkey: String!
    let key: String
    let created: TimeInterval
    let userSyncPubkey: String
    let isAdmin: Bool
    let name: String

    static let CRYPTO_CONTEXT = "keynteam"

    func encrypt(key: Data) throws -> String {
        let data = try JSONEncoder().encode(self)
        let ciphertext = try Crypto.shared.encryptSymmetric(data, secretKey: key)
        return try Crypto.shared.convertToBase64(from: ciphertext)
    }

    func encryptAccount(account: TeamAccount) throws -> String {
        guard let site = account.sites.first else {
            throw CodingError.missingData
        }
        guard let key = key.fromBase64 else {
            throw CodingError.stringDecoding
        }
        guard let password = account.password else {
            throw CodingError.missingData
        }
        let passwordSeed = try Crypto.shared.deriveKey(keyData: key, context: TeamUser.CRYPTO_CONTEXT, index: 0)
        let encryptionKey = try Crypto.shared.deriveKey(keyData: key, context: TeamUser.CRYPTO_CONTEXT, index: 1)
        let generator = PasswordGenerator(username: account.username, siteId: site.id, ppd: site.ppd, passwordSeed: passwordSeed)
        let offset = try generator.calculateOffset(index: 0, password: password)
        let backupAccount = BackupSharedAccount(id: account.id, username: account.username, sites: account.sites, passwordIndex: 0, passwordOffset: offset, tokenURL: nil, tokenSecret: nil, version: account.version)
        let data = try JSONEncoder().encode(backupAccount)
        return try Crypto.shared.encrypt(data, key: encryptionKey).base64
    }
}

extension TeamUser: Hashable {

    static func == (lhs: TeamUser, rhs:TeamUser) -> Bool {
        return lhs.pubkey == rhs.pubkey
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(pubkey)
    }

}

extension TeamUser: AccessControllable {

    var id: String {
        return pubkey
    }

}

