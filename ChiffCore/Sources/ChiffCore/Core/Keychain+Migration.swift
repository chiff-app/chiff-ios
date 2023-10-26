//
//  Keychain+Migration.swift
//  ChiffCore
//
//  Copyright: see LICENSE.md
//

import Foundation
import LocalAuthentication

extension Keychain {

    public func migrate(context: LAContext?) {
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
                fallthrough
            case let n where n < 2:
                try migrateKeychainGroup(id: KeyIdentifier.password.identifier(for: .passwordSeed), service: .passwordSeed, oldGroup: "35MFYY2JY5.io.keyn.keyn", context: context)
                try migrateKeychainGroup(id: nil, service: .backup, oldGroup: "35MFYY2JY5.io.keyn.keyn", context: context)
                try migrateKeychainGroup(id: nil, service: .account(attribute: nil), oldGroup: "35MFYY2JY5.io.keyn.confidential", context: context)
                try migrateKeychainGroup(id: nil, service: .sharedAccount(attribute: nil), oldGroup: "35MFYY2JY5.io.keyn.confidential", context: context)
                try migrateKeychainGroup(id: nil, service: .account(attribute: .webauthn), oldGroup: "35MFYY2JY5.io.keyn.confidential", context: context)
                try migrateKeychainGroup(id: nil, service: .account(attribute: .notes), oldGroup: "35MFYY2JY5.io.keyn.keyn", context: context)
                try migrateKeychainGroup(id: nil, service: .account(attribute: .otp), oldGroup: "35MFYY2JY5.io.keyn.keyn", context: context)
                try migrateKeychainGroup(id: nil, service: .sharedAccount(attribute: .notes), oldGroup: "35MFYY2JY5.io.keyn.keyn", context: context)
                try migrateKeychainGroup(id: nil, service: .sharedAccount(attribute: .otp), oldGroup: "35MFYY2JY5.io.keyn.keyn", context: context)
                Properties.currentKeychainVersion = 2
            case let n where n < 3:
                try migrateKeychainGroup(id: KeyIdentifier.webauthn.identifier(for: .seed), service: .seed, oldGroup: "35MFYY2JY5.io.keyn.keyn", context: context)
                Properties.currentKeychainVersion = 3
            default:
                return
            }
        } catch {
            Logger.shared.error("Failed to update Keychain.", error: error)
        }
    }

    // MARK: - Private functions

    private func migrateKeychainGroup(id identifier: String?, service: KeychainService, oldGroup: String, context: LAContext?) throws {
        var query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service.service,
                                    kSecAttrAccessGroup as String: oldGroup,
                                    kSecMatchLimit as String: kSecMatchLimitAll,
                                    kSecReturnAttributes as String: true,
                                    kSecUseAuthenticationUI as String: kSecUseAuthenticationUIFail]

        if let identifier = identifier {
            query[kSecAttrAccount as String] = identifier
        }

        if let defaultContext = service.defaultContext {
            query[kSecUseAuthenticationContext as String] = context ?? defaultContext
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
                let attributes: [String: Any] = [
                    kSecAttrAccessGroup as String: service.accessGroup,
                ]
                var updateQuery: [String: Any] = [kSecClass as String:  kSecClassGenericPassword,
                                                  kSecAttrAccount as String: id,
                                                  kSecAttrAccessGroup as String: oldGroup,
                                                  kSecAttrService as String: service.service,
                                                  kSecUseAuthenticationUI as String: kSecUseAuthenticationUIFail]

                if let defaultContext = service.defaultContext {
                    updateQuery[kSecUseAuthenticationContext as String] = context ?? defaultContext
                }

                switch SecItemUpdate(updateQuery as CFDictionary, attributes as CFDictionary) {
                case errSecSuccess, errSecDuplicateItem: break
                case -26276, errSecInteractionNotAllowed:
                    throw KeychainError.interactionNotAllowed
                case let status:
                    throw KeychainError.unhandledError(status.message)
                }
            }
        }
    }

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
