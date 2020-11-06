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

/// Wrapper around the Keychain.
struct Keychain {

    static let shared = Keychain()

    private init() {}

    // MARK: - Unauthenticated Keychain operations

    /// Save an object in the keychain. `secretData` and/or `objectData` must be present.
    /// - Parameters:
    ///   - identifier: The objects identifier, which should be unique.
    ///   - service: The service, which determines access group and accessibility.
    ///   - secretData: The secret data.
    ///   - objectData: The object data.
    ///   - label: A label, which can serve as a index for queries.
    /// - Throws:
    ///   - `KeychainError.noData` when either `secretData` or `objectData` is missing.
    ///   - `KeychainError.interactionNotAllowed` when trying to save an object while the user is not authenticated.
    ///   - `KeychainError.duplicateItem` when an item with this id already exists.
    ///   - `KeychainError.unhandledError(status.message)` for any other Keychain error.
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

    /// Retrieves the secret data of an object the keychain.
    /// - Precondition: This is the synchronous version, which only works if the `LAContext` (provided or main) is authenticated.
    ///     Use the asynchronous version to ask if this not the case
    /// - Parameters:
    ///   - identifier: The objects identifier, which should be unique.
    ///   - service: The service, which determines access group and accessibility.
    ///   - context: Optionally, an authenticated `LAContext`. Uses the main `LAContext` otherwise.
    /// - Throws:
    ///   - `KeychainError.interactionNotAllowed` when trying to save an object while the user is not authenticated.
    ///   - `KeychainError.unexpectedData` when the cannot be decoded.
    ///   - `KeychainError.unhandledError(status.message)` for any other Keychain error.
    /// - Returns: The data, or nil if item was not found.
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

    /// Checks if an item exists in the keychain.
    /// - Parameters:
    ///   - identifier: The objects identifier, which should be unique.
    ///   - service: The service, which determines access group and accessibility.
    ///   - context: Optionally, an authenticated `LAContext`. Uses the main `LAContext` otherwise.
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

    /// Updates the data of an object the keychain.
    /// - Precondition: This operation only works if the `LAContext` (provided or main) is authenticated.
    /// - Parameters:
    ///   - identifier: The objects identifier, which should be unique.
    ///   - service: The service, which determines access group and accessibility.
    ///   - secretData: The secret data.
    ///   - objectData: The object data.
    ///   - context: Optionally, an authenticated `LAContext`. Uses the main `LAContext` otherwise.
    /// - Throws:
    ///   - `KeychainError.interactionNotAllowed` when trying to save an object while the user is not authenticated.
    ///   - `KeychainError.notFound` when item is not found.
    ///   - `KeychainError.unhandledError(status.message)` for any other Keychain error.
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

    /// Retrieves the object data of all objects for a service.
    /// - Precondition: Only works if the `LAContext` (provided or main) is authenticated.
    /// - Parameters:
    ///   - service: The service, which determines access group and accessibility.
    ///   - context: Optionally, an authenticated `LAContext`. Uses the main `LAContext`
    ///   - label: Optionally, a label on which the results should be filtered.
    /// - Throws:
    ///   - `KeychainError.interactionNotAllowed` when trying to save an object while the user is not authenticated.
    ///   - `KeychainError.unexpectedData` when the cannot be decoded.
    ///   - `KeychainError.unhandledError(status.message)` for any other Keychain error.
    /// - Returns: The data, or nil if item was not found.
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

    /// Retrieves the object data of an item in the keychain.
    /// - Precondition: This is the synchronous version, which only works if the `LAContext` (provided or main) is authenticated.
    /// - Parameters:
    ///   - identifier: The object's unique identifier
    ///   - service: The service, which determines access group and accessibility.
    ///   - context: Optionally, an authenticated `LAContext`. Uses the main `LAContext` otherwise.
    /// - Throws:
    ///   - `KeychainError.interactionNotAllowed` when trying to save an object while the user is not authenticated.
    ///   - `KeychainError.unexpectedData` when the cannot be decoded.
    ///   - `KeychainError.unhandledError(status.message)` for any other Keychain error.
    /// - Returns: The data, or nil if item was not found.
    func attributes(id identifier: String, service: KeychainService, context: LAContext? = nil) throws -> Data? {
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

        guard let data = dataArray[kSecAttrGeneric as String] as? Data else {
            throw KeychainError.unexpectedData
        }

        return data
    }

    /// Delete an item from the keychain.
    /// - Parameters:
    ///   - identifier: The object's unique identifier
    ///   - service: The service, which determines access group and accessibility.
    /// - Throws: `KeychainError.notFound` when item is not found.
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

    /// Deletes all items for a given service and/or label from the keychain.
    /// - Parameters:
    ///   - service: The service, which determines access group and accessibility.
    ///   - label: Optionally, a label on which the results should be filtered.
    /// - Throws: `KeychainError.notFound` when item is not found.
    func deleteAll(service: KeychainService, label: String? = nil) {
        var query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service.rawValue]
        if let label = label {
            query[kSecAttrLabel as String] = label
        }
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Authenticated Keychain operations

    /// Retrieves the secret data of an object the keychain.
    ///
    /// This operation ask the user to authenticate the operation if necessary. This is handled on a custom OperationQueue that is managed by LocalAuthenticationManager.shared
    /// - Parameters:
    ///   - identifier: The objects identifier, which should be unique.
    ///   - service: The service, which determines access group and accessibility.
    ///   - context: Optionally, an authenticated `LAContext`. Uses the main `LAContext` otherwise.
    ///   - reason: The reason to present to the user
    ///   - type: Determines what to do with the `LAContext`.
    /// - Throws:
    ///   - `KeychainError.interactionNotAllowed` when trying to save an object while the user is not authenticated.
    ///   - `KeychainError.unexpectedData` when the cannot be decoded.
    ///   - `KeychainError.unhandledError(status.message)` for any other Keychain error.
    /// - Returns: The data, or nil if item was not found.
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

}
