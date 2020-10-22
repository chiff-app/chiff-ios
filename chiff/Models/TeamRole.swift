//
//  TeamRole.swift
//  keyn
//
//  Created by Bas Doorn on 17/03/2020.
//  Copyright © 2020 keyn. All rights reserved.
//

import Foundation

struct TeamRole: Codable, AccessControllable {
    let id: String
    let name: String
    let admins: Bool
    var users: [String]

    func encrypt(key: Data) throws -> String {
        let data = try JSONEncoder().encode(self)
        let ciphertext = try Crypto.shared.encryptSymmetric(data, secretKey: key)
        return try Crypto.shared.convertToBase64(from: ciphertext)
    }
}

extension TeamRole: Hashable {

    static func == (lhs: TeamRole, rhs: TeamRole) -> Bool {
        return lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

}
