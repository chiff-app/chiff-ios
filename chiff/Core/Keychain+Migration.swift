//
//  Keychain+Migration.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import Foundation
import LocalAuthentication
import ChiffCore

extension Keychain {

    /// Checks if the Keychain needs upgrading to the latest version. Does nothing if already up to date
    /// - Parameter context: An authenticated `LAContext` object.
    func migrate(context: LAContext?) {
        guard Properties.currentKeychainVersion < Properties.latestKeychainVersion else {
            return
        }
        do {
            switch Properties.currentKeychainVersion {
            case let n where n == 0:
                // Save OTP and notes separately for a shared accounts.
                try migrateService(oldService: "io.keyn.otp", attribute: .otp, includeSharedAccount: true, context: context)
                try migrateService(oldService: "io.keyn.notes", attribute: .notes, includeSharedAccount: true, context: context)
                try migrateService(oldService: "io.keyn.webauthn", attribute: .webauthn, includeSharedAccount: false, context: context)
                Properties.currentKeychainVersion = 1
            default:
                return
            }
        } catch {
            Logger.shared.error("Failed to update Keychain.", error: error)
        }
    }

    // MARK: - Private functions

    private func migrateService(oldService: String, attribute: KeychainService.AccountAttribute, includeSharedAccount: Bool, context: LAContext?) throws {
        var query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: oldService,
                                    kSecMatchLimit as String: kSecMatchLimitAll,
                                    kSecReturnData as String: true,
                                    kSecReturnAttributes as String: true,
                                    kSecUseAuthenticationUI as String: kSecUseAuthenticationUIFail]

        if let context = context {
            query[kSecUseAuthenticationContext as String] = context
        }

        var queryResult: AnyObject?
        switch SecItemCopyMatching(query as CFDictionary, &queryResult) {
        case errSecSuccess: break
        case errSecItemNotFound: return
        case -26276, errSecInteractionNotAllowed:
            throw KeychainError.interactionNotAllowed
        case let status:
            throw KeychainError.unhandledError(status.message)
        }

        guard let dataArray = queryResult as? [[String: Any]] else {
            throw KeychainError.unexpectedData
        }
        for dict in dataArray {
            if let id = dict[kSecAttrAccount as String] as? String {
                let attributeData = dict[kSecAttrGeneric as String] as? Data
                let secretData = dict[kSecValueData as String] as? Data
                guard attributeData != nil || secretData != nil else {
                    continue
                }
                // Is there a UserAccount with this ID?
                if Keychain.shared.has(id: id, service: .account(attribute: nil)) {
                    // Save to the new service
                    try Keychain.shared.save(id: id, service: .account(attribute: attribute), secretData: secretData, objectData: attributeData)
                }
                // Is there a SharedAccount with this ID?
                if includeSharedAccount && Keychain.shared.has(id: id, service: .sharedAccount(attribute: nil)) {
                    // Save to the new service
                    try Keychain.shared.save(id: id, service: .sharedAccount(attribute: attribute), secretData: secretData, objectData: attributeData)
                }
                // Delete the old item if no errors are thrown.
                try deleteItem(id: id, service: oldService)
            }
        }
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
