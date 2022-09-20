//
//  Keychain.swift
//  ChiffCore
//
//  Copyright: see LICENSE.md
//

import Foundation
import LocalAuthentication
import CryptoKit
import PromiseKit

public enum KeychainError: Error {
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

public protocol KeychainProtocol {
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
    func save(id identifier: String, service: KeychainService, secretData: Data?, objectData: Data?, label: String?) throws

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
    func get(id identifier: String, service: KeychainService, context: LAContext?) throws -> Data?

    /// Checks if an item exists in the keychain.
    /// - Parameters:
    ///   - identifier: The objects identifier, which should be unique.
    ///   - service: The service, which determines access group and accessibility.
    ///   - context: Optionally, an authenticated `LAContext`. Uses the main `LAContext` otherwise.
    func has(id identifier: String, service: KeychainService, context: LAContext?) -> Bool

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
    func update(id identifier: String, service: KeychainService, secretData: Data?, objectData: Data?, context: LAContext?) throws

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
    func all(service: KeychainService, context: LAContext?, label: String?) throws -> [[String: Any]]?

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
    func attributes(id identifier: String, service: KeychainService, context: LAContext?) throws -> Data?

    /// Delete an item from the keychain.
    /// - Parameters:
    ///   - identifier: The object's unique identifier
    ///   - service: The service, which determines access group and accessibility.
    /// - Throws: `KeychainError.notFound` when item is not found.
    func delete(id identifier: String, service: KeychainService) throws

    /// Deletes all items for a given service and/or label from the keychain.
    /// - Parameters:
    ///   - service: The service, which determines access group and accessibility.
    ///   - label: Optionally, a label on which the results should be filtered.
    /// - Throws: `KeychainError.notFound` when item is not found.
    func deleteAll(service: KeychainService, label: String?)

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
    func get(id identifier: String, service: KeychainService, reason: String, with context: LAContext?, authenticationType type: AuthenticationType) -> Promise<Data?>

    /// Stores a CryptoKit key in the keychain as a SecKey instance.
    /// - Parameters:
    ///   - identifier: The unique idenitfier
    ///   - key: A `SecKeyConvertible` key.
    /// - Throws: `KeychainError.createSecKey` when fails to creaate a key, unhandledErro otherwise
    @available(iOS 13.0, *)
    func saveKey<T: SecKeyConvertible>(id identifier: String, key: T) throws

    /// Reads a CryptoKit key from the keychain as a SecKey instance.
    /// - Parameters:
    ///   - identifier: The item's unique identifier
    ///   - context: Optionally, an authenticated `LAContext` object.
    /// - Throws:
    ///   - `KeychainError.interactionNotAllowed` if the `LAContext` is not authenticated.
    ///   - `KeychainError.unhandledError` for any other error.
    /// - Returns: The key.
    @available(iOS 13.0, *)
    func getKey<T: SecKeyConvertible>(id identifier: String, context: LAContext?) throws -> T?

    /// Deletes a key from the Keychain
    /// - Parameter identifier: The item's unique identifier
    /// - Throws:
    ///   - `KeychainError.notFound` if the item is not found.
    ///   - `KeychainError.unhandledError` for any other error.
    func deleteKey(id identifier: String) throws

    /// Delete all keys from the Keychain.
    /// - Throws:
    ///   - `KeychainError.notFound` if the item is not found.
    ///   - `KeychainError.unhandledError` for any other error.
    func deleteAllKeys()

    /// Checks if the Keychain needs upgrading to the latest version. Does nothing if already up to date
    /// - Parameter context: An authenticated `LAContext` object.
    func migrate(context: LAContext?)
}

// Extension for default parameters
public extension KeychainProtocol {

    func save(id identifier: String, service: KeychainService, secretData: Data?, objectData: Data? = nil, label: String? = nil) throws {
        return try save(id: identifier, service: service, secretData: secretData, objectData: objectData, label: label)
    }

    func get(id identifier: String, service: KeychainService, context: LAContext? = nil) throws -> Data? {
        return try get(id: identifier, service: service, context: context)
    }

    func has(id identifier: String, service: KeychainService, context: LAContext? = nil) -> Bool {
        return has(id: identifier, service: service, context: context)
    }

    func update(id identifier: String, service: KeychainService, secretData: Data? = nil, objectData: Data? = nil, context: LAContext? = nil) throws {
        return try update(id: identifier, service: service, secretData: secretData, objectData: objectData, context: context)
    }

    func all(service: KeychainService, context: LAContext? = nil, label: String? = nil) throws -> [[String: Any]]? {
        return try all(service: service, context: context, label: label)
    }

    func attributes(id identifier: String, service: KeychainService, context: LAContext? = nil) throws -> Data? {
        return try attributes(id: identifier, service: service, context: context)
    }

    func deleteAll(service: KeychainService, label: String? = nil) {
        return deleteAll(service: service, label: label)
    }

    func get(id identifier: String, service: KeychainService, reason: String, with context: LAContext? = nil, authenticationType type: AuthenticationType) -> Promise<Data?> {
        return get(id: identifier, service: service, reason: reason, with: context, authenticationType: type)
    }

}
