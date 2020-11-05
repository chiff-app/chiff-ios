//
//  Keychain.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import Foundation
import LocalAuthentication
import CryptoKit
import PromiseKit

enum KeychainError: Error {
    case stringEncoding
    case unexpectedData
    case storeKey
    case notFound
    case unhandledError(String)
    case noData
    case interactionNotAllowed
    case failedCreatingSecAccess
    case authenticationCancelled
    case createSecKey
    case duplicateItem
}

enum KeychainService: String {
    case account = "io.keyn.account"
    case sharedAccount = "io.keyn.sharedaccount"
    case otp = "io.keyn.otp"
    case webauthn = "io.keyn.webauthn"
    case notes = "io.keyn.notes"
    case seed = "io.keyn.seed"
    case sharedSessionKey = "io.keyn.session.shared"
    case signingSessionKey = "io.keyn.session.signing"
    case sharedTeamSessionKey = "io.keyn.teamsession.shared"
    case signingTeamSessionKey = "io.keyn.teamsession.signing"
    case aws = "io.keyn.aws"
    case backup = "io.keyn.backup"

    var classification: Classification {
        switch self {
        case .sharedSessionKey, .signingSessionKey, .sharedTeamSessionKey, .signingTeamSessionKey:
            return .restricted
        case .account, .sharedAccount, .webauthn:
            return .confidential
        case .aws, .backup:
            return .secret
        case .seed, .otp, .notes:
            return .topsecret
        }
    }

    var accessGroup: String {
        switch self.classification {
        case .restricted:
            return "35MFYY2JY5.io.keyn.restricted"
        case .confidential:
            return "35MFYY2JY5.io.keyn.confidential"
        case .secret, .topsecret:
            return "35MFYY2JY5.io.keyn.keyn"
        }
    }

    var defaultContext: LAContext? {
        return (self.classification == .confidential || self.classification == .topsecret) ? LocalAuthenticationManager.shared.mainContext : nil
    }

    enum Classification {
        case restricted
        case confidential
        case secret
        case topsecret
    }
}

struct Keychain {

    static let shared = Keychain()

    private init() {}

    // MARK: - Unauthenticated Keychain operations
    // These can be synchronous because they never call LocalAuthentication

    func save(id identifier: String, service: KeychainService, secretData: Data?, objectData: Data? = nil, label: String? = nil) throws {
        guard secretData != nil || objectData != nil else {
            throw KeychainError.noData
        }
        var query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrAccount as String: identifier,
                                    kSecAttrService as String: service.rawValue,
                                    kSecAttrAccessGroup as String: service.accessGroup]
        if let objectData = objectData {
            query[kSecAttrGeneric as String] = objectData
        }
        if let secretData = secretData {
            query[kSecValueData as String] = secretData
        }
        if let label = label {
            query[kSecAttrLabel as String] = label
        }

        switch service.classification {
        case .restricted:
            query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        case .secret:
            query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        case .confidential, .topsecret:
            let access = SecAccessControlCreateWithFlags(nil, // Use the default allocator.
                kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                .userPresence,
                nil) // Ignore any error.
            query[kSecAttrAccessControl as String] = access
        }

        switch SecItemAdd(query as CFDictionary, nil) {
        case errSecSuccess: break
        case -26276, errSecInteractionNotAllowed:
            throw KeychainError.interactionNotAllowed
        case errSecDuplicateItem:
            throw KeychainError.duplicateItem
        case let status:
             throw KeychainError.unhandledError(status.message)
        }
    }

    func get(id identifier: String, service: KeychainService, context: LAContext? = nil) throws -> Data? {
        var query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrAccount as String: identifier,
                                    kSecAttrService as String: service.rawValue,
                                    kSecMatchLimit as String: kSecMatchLimitOne,
                                    kSecReturnData as String: true,
                                    kSecUseAuthenticationUI as String: kSecUseAuthenticationUIFail]

        if let defaultContext = service.defaultContext {
            query[kSecUseAuthenticationContext as String] = context ?? defaultContext
        }

        var queryResult: AnyObject?
        switch SecItemCopyMatching(query as CFDictionary, &queryResult) {
        case errSecSuccess: break
        case -26276, errSecInteractionNotAllowed:
            throw KeychainError.interactionNotAllowed
        case errSecItemNotFound:
            return nil
        case let status:
            throw KeychainError.unhandledError(status.message)
        }
        guard queryResult != nil else {
            return nil
        }
        guard let data = queryResult as? Data else {
            throw KeychainError.unexpectedData
        }

        return data
    }

    func has(id identifier: String, service: KeychainService, context: LAContext? = nil) -> Bool {
        var query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrAccount as String: identifier,
                                    kSecAttrService as String: service.rawValue,
                                    kSecMatchLimit as String: kSecMatchLimitOne,
                                    kSecUseAuthenticationUI as String: kSecUseAuthenticationUIFail]

        if let defaultContext = service.defaultContext {
            query[kSecUseAuthenticationContext as String] = context ?? defaultContext
        }

        return SecItemCopyMatching(query as CFDictionary, nil) != errSecItemNotFound
    }

    func update(id identifier: String, service: KeychainService, secretData: Data? = nil, objectData: Data? = nil, context: LAContext? = nil) throws {
        var query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrAccount as String: identifier,
                                    kSecAttrService as String: service.rawValue,
                                    kSecUseAuthenticationUI as String: kSecUseAuthenticationUIFail]

        if let defaultContext = service.defaultContext {
            query[kSecUseAuthenticationContext as String] = context ?? defaultContext
        }

        guard secretData != nil || objectData != nil else {
            throw KeychainError.noData
        }

        var attributes = [String: Any]()

        if secretData != nil {
            attributes[kSecValueData as String] = secretData
        }

        if objectData != nil {
            attributes[kSecAttrGeneric as String] = objectData
        }

        switch SecItemUpdate(query as CFDictionary, attributes as CFDictionary) {
        case errSecSuccess: return
        case -26276, errSecInteractionNotAllowed:
            throw KeychainError.interactionNotAllowed
        case errSecItemNotFound:
            throw KeychainError.notFound
        case let status:
            throw KeychainError.unhandledError(status.message)
        }
    }

    func all(service: KeychainService, context: LAContext? = nil, label: String? = nil) throws -> [[String: Any]]? {
        var query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service.rawValue,
                                    kSecMatchLimit as String: kSecMatchLimitAll,
                                    kSecReturnAttributes as String: true,
                                    kSecUseAuthenticationUI as String: kSecUseAuthenticationUIFail]

        if let defaultContext = service.defaultContext {
            query[kSecUseAuthenticationContext as String] = context ?? defaultContext
        }
        if let label = label {
            query[kSecAttrLabel as String] = label
        }

        var queryResult: AnyObject?
        switch SecItemCopyMatching(query as CFDictionary, &queryResult) {
        case errSecSuccess: break
        case errSecItemNotFound: return nil
        case -26276, errSecInteractionNotAllowed:
            throw KeychainError.interactionNotAllowed
        case let status:
            throw KeychainError.unhandledError(status.message)
        }

        guard let dataArray = queryResult as? [[String: Any]] else {
            throw KeychainError.unexpectedData
        }

        return dataArray
    }

    func attributes(id identifier: String, service: KeychainService, context: LAContext? = nil) throws -> [String: Any]? {
        var query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrAccount as String: identifier,
                                    kSecAttrService as String: service.rawValue,
                                    kSecMatchLimit as String: kSecMatchLimitOne,
                                    kSecReturnAttributes as String: true,
                                    kSecUseAuthenticationUI as String: kSecUseAuthenticationUIFail]

        if let defaultContext = service.defaultContext {
            query[kSecUseAuthenticationContext as String] = context ?? defaultContext
        }

        var queryResult: AnyObject?
        switch SecItemCopyMatching(query as CFDictionary, &queryResult) {
        case errSecSuccess: break
        case errSecItemNotFound: return nil
        case -26276, errSecInteractionNotAllowed:
            throw KeychainError.interactionNotAllowed
        case let status:
            throw KeychainError.unhandledError(status.message)
        }

        guard let dataArray = queryResult as? [String: Any] else {
            throw KeychainError.unexpectedData
        }
        return dataArray
    }

    func delete(id identifier: String, service: KeychainService) throws {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrAccount as String: identifier,
                                    kSecAttrService as String: service.rawValue]

        switch SecItemDelete(query as CFDictionary) {
        case errSecSuccess: break
        case errSecItemNotFound: throw KeychainError.notFound
        case let status:
            throw KeychainError.unhandledError(status.message)
        }
    }

    func deleteAll(service: KeychainService, label: String? = nil) {
        var query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service.rawValue]
        if let label = label {
            query[kSecAttrLabel as String] = label
        }
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Authenticated Keychain operations
    // These operations ask the user to authenticate the operation if necessary. This is handled on a custom OperationQueue that is managed by LocalAuthenticationManager.shared

    func get(id identifier: String, service: KeychainService, reason: String, with context: LAContext? = nil, authenticationType type: AuthenticationType) -> Promise<Data?> {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrAccount as String: identifier,
                                    kSecAttrService as String: service.rawValue,
                                    kSecMatchLimit as String: kSecMatchLimitOne,
                                    kSecReturnData as String: true,
                                    kSecUseOperationPrompt as String: reason]
        return Promise { seal in
            do {
                try LocalAuthenticationManager.shared.execute(query: query, type: type) { (query, _) in
                    var queryResult: AnyObject?
                    switch SecItemCopyMatching(query as CFDictionary, &queryResult) {
                    case errSecSuccess: break
                    case errSecItemNotFound:
                        seal.fulfill(nil)
                    case errSecInteractionNotAllowed:
                        seal.reject(KeychainError.interactionNotAllowed)
                    case let status:
                        seal.reject(KeychainError.unhandledError(status.message))
                    }

                    guard let result = queryResult else {
                        return seal.fulfill(nil)
                    }
                    guard let data = result as? Data else {
                        return seal.reject(KeychainError.unexpectedData)
                    }
                    seal.fulfill(data)
                }
            } catch {
                seal.reject(error)
            }
        }
    }

    func delete(id identifier: String, service: KeychainService, reason: String, authenticationType type: AuthenticationType, with context: LAContext? = nil) -> Promise<LAContext?> {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrAccount as String: identifier,
                                    kSecAttrService as String: service.rawValue]
        return Promise { seal in
            do {
                try LocalAuthenticationManager.shared.execute(query: query, type: type) { (query, context) in
                    switch SecItemDelete(query as CFDictionary) {
                    case errSecItemNotFound:
                        seal.reject(KeychainError.notFound)
                    case errSecSuccess:
                        seal.fulfill(context)
                    case let status:
                        seal.reject(KeychainError.unhandledError(status.message))
                    }
                }
            } catch {
                seal.reject(error)
            }
        }
    }

}
