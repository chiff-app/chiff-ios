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

    /// Migrate outdated accounts to the current version
    /// - Parameter context: Optionally, an `LAContext`.
    mutating func updateVersion(context: LAContext?) {
        do {
            guard version == 0 else {
                return
            }
            try updatePassword(context: context)
            version = 1
            self.lastChange = Date.now
            let accountData = try PropertyListEncoder().encode(self)
            try Keychain.shared.update(id: id, service: .account(attribute: nil), secretData: nil, objectData: accountData, context: nil)
            _ = try backup()
        } catch {
            Logger.shared.warning("Error updating account version", error: error, userInfo: nil)
        }
    }

    // MARK: - Private functions

    private mutating func updatePassword(context: LAContext?) throws {
        guard let password = try password() else {
            // WebAuthn account
            return
        }
        let generator = PasswordGenerator(username: username, siteId: site.id, ppd: site.ppd, passwordSeed: try Seed.getPasswordSeed(context: context), version: 1)
        passwordOffset = try generator.calculateOffset(index: passwordIndex, password: password)
    }

}
