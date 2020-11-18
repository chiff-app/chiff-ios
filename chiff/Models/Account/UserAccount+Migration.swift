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
        var save = false
        do {
            switch version {
            case let n where n == 0:
                try updatePassword(context: context)
                version = 1
                save = true
                fallthrough
            case let n where n == 1:
                try migrateService(id: id, oldService: "io.keyn.otp", newService: .account(attribute: .otp), context: context)
                try migrateService(id: id, oldService: "io.keyn.notes", newService: .account(attribute: .notes), context: context)
                try migrateService(id: id, oldService: "io.keyn.webauthn", newService: .account(attribute: .webauthn), context: context)
                version = 2
                save = true
            default:
                return
            }
        } catch {
            Logger.shared.warning("Error updating account version", error: error, userInfo: nil)
        }
        do {
            if save {
                self.lastChange = Date.now
                let accountData = try PropertyListEncoder().encode(self)
                try Keychain.shared.update(id: id, service: .account(attribute: nil), secretData: nil, objectData: accountData, context: nil)
                _ = try backup()
            }
        } catch {
            Logger.shared.warning("Error saving account after updating version", error: error, userInfo: nil)
        }

    }

    // MARK: - Private functions

    private mutating func updatePassword(context: LAContext?) throws {
        guard let password = try password() else {
            throw KeychainError.notFound
        }
        let generator = PasswordGenerator(username: username, siteId: site.id, ppd: site.ppd, passwordSeed: try Seed.getPasswordSeed(context: context), version: 1)
        passwordOffset = try generator.calculateOffset(index: passwordIndex, password: password)
    }

    private func migrateService(id identifier: String, oldService: String, newService: KeychainService, context: LAContext?) throws {
        // Get the old item from the keychain
        let (secret, attributes) = try getItem(id: identifier, service: oldService, context: context ?? newService.defaultContext)
        guard let data = secret else {
            return
        }

        // Save to the new service
        try Keychain.shared.save(id: identifier, service: newService, secretData: data, objectData: attributes)

        // Delete the old item if no errors are thrown.
        try deleteItem(id: identifier, service: oldService)
    }

    private func getItem(id identifier: String, service: String, context: LAContext?) throws -> (Data?, Data?) {
        var query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrAccount as String: identifier,
                                    kSecAttrService as String: service,
                                    kSecMatchLimit as String: kSecMatchLimitOne,
                                    kSecReturnData as String: true,
                                    kSecReturnAttributes as String: true,
                                    kSecUseAuthenticationUI as String: kSecUseAuthenticationUIFail]

        if let context = context {
            query[kSecUseAuthenticationContext as String] = context
        }

        // Check if the item exists. If not, return false
        var queryResult: AnyObject?
        switch SecItemCopyMatching(query as CFDictionary, &queryResult) {
        case errSecSuccess: break
        case -26276, errSecInteractionNotAllowed:
            throw KeychainError.interactionNotAllowed
        case errSecItemNotFound:
            return (nil, nil)
        case let status:
            throw KeychainError.unhandledError(status.message)
        }
        guard let dataArray = queryResult as? [String: Any] else {
            throw KeychainError.unexpectedData
        }
        guard let data = dataArray[kSecValueData as String] as? Data else {
            throw KeychainError.unexpectedData
        }
        let attributes = dataArray[kSecAttrGeneric as String] as? Data
        return (data, attributes)
    }

    private func deleteItem(id identifier: String, service: String) throws {
        let deleteQuery: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrAccount as String: identifier,
                                    kSecAttrService as String: service]

        switch SecItemDelete(deleteQuery as CFDictionary) {
        case errSecSuccess: break
        case errSecItemNotFound: throw KeychainError.notFound
        case let status:
            throw KeychainError.unhandledError(status.message)
        }
    }

}
