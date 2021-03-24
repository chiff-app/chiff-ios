//
//  TeamRole.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import Foundation
import ChiffCore

/// A team role.
struct TeamRole: Codable, AccessControllable {
    let id: String
    let name: String
    let admins: Bool
    var users: [String]

    /// Encrypt this role with a given key.
    /// - Parameter key: The encryption key.
    /// - Throws: Encryption or coding errors.
    /// - Returns: The base64 encoded ciphertext.
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
