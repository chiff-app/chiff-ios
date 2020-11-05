//
//  UserAccount+Migration.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import Foundation
import LocalAuthentication

// Version migration
extension UserAccount {

    mutating func updateVersion(context: LAContext?) {
        guard version == 0 else {
            return
        }
        do {
            guard let password = try password() else {
                throw KeychainError.notFound
            }
            let generator = PasswordGenerator(username: username, siteId: site.id, ppd: site.ppd, passwordSeed: try Seed.getPasswordSeed(context: context), version: 1)
            passwordOffset = try generator.calculateOffset(index: passwordIndex, password: password)
            version = 1
            let accountData = try PropertyListEncoder().encode(self)
            try Keychain.shared.update(id: id, service: .account, secretData: nil, objectData: accountData, context: nil)
            _ = try backup()
        } catch {
            Logger.shared.warning("Error updating account version", error: error, userInfo: nil)
        }

    }
}
