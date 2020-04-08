//
//  TeamAccount.swift
//  keyn
//
//  Created by Bas Doorn on 17/03/2020.
//  Copyright © 2020 keyn. All rights reserved.
//

import Foundation

struct TeamAccount: BaseAccount {
    let id: String
    var username: String
    var passwordOffset: [Int]?
    var passwordIndex: Int
    var sites: [Site]
    let version: Int
    let users: Set<String>
    let roles: Set<String>
    let compromised: Bool

    init(account: Account, seed: Data, users: [TeamUser], roles: [TeamRole], version: Int = 1) throws {
        self.id = account.id
        self.username = account.username
        self.sites = account.sites
        self.users = Set(users.map { $0.pubkey! })
        self.roles = Set(roles.map { $0.id })
        self.version = version
        self.compromised = false

        if let password = try account.password() {
            let passwordGenerator = PasswordGenerator(username: username, siteId: sites[0].id, ppd: sites[0].ppd, passwordSeed: seed)
            self.passwordIndex = 0
            self.passwordOffset = try passwordGenerator.calculateOffset(index: self.passwordIndex, password: password)
        } else {
            self.passwordOffset = nil
            self.passwordIndex = -1
        }
    }

    func password(for seed: Data) throws -> String {
        let passwordGenerator = PasswordGenerator(username: username, siteId: sites[0].id, ppd: sites[0].ppd, passwordSeed: seed)
        return (try passwordGenerator.generate(index: passwordIndex, offset: passwordOffset)).0
    }

    func encrypt(key: Data) throws -> String {
        let data = try JSONEncoder().encode(self)
        let ciphertext = try Crypto.shared.encryptSymmetric(data, secretKey: key)
        return try Crypto.shared.convertToBase64(from: ciphertext)
    }

}

extension TeamAccount: Hashable {

    static func == (lhs: TeamAccount, rhs:TeamAccount) -> Bool {
        return lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension TeamAccount: Codable {
    
    enum CodingKeys: CodingKey {
        case id
        case username
        case passwordIndex
        case passwordOffset
        case sites
        case users
        case roles
        case compromised
        case version
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try values.decode(String.self, forKey: .id)
        self.username = try values.decode(String.self, forKey: .username)
        self.passwordIndex = try values.decode(Int.self, forKey: .passwordIndex)
        self.passwordOffset = try values.decodeIfPresent([Int].self, forKey: .passwordOffset)
        self.sites = try values.decode([Site].self, forKey: .sites)
        self.users = try values.decode(Set<String>.self, forKey: .users)
        self.roles = try values.decode(Set<String>.self, forKey: .roles)
        self.compromised = try values.decode(Bool.self, forKey: .compromised)
        self.version = try values.decode(Int.self, forKey: .version)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(username, forKey: .username)
        try container.encode(passwordIndex, forKey: .passwordIndex)
        try container.encode(passwordOffset, forKey: .passwordOffset)
        try container.encode(sites, forKey: .sites)
        try container.encode(users, forKey: .users)
        try container.encode(roles, forKey: .roles)
        try container.encode(compromised, forKey: .compromised)
        try container.encode(version, forKey: .version)
    }

}
