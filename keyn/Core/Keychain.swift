/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import Foundation
import Security
import LocalAuthentication

enum KeychainError: KeynError {
    case stringEncoding
    case unexpectedData
    case storeKey
    case notFound
    case unhandledError(OSStatus)
    case noData
    case interactionNotAllowed
    case failedCreatingSecAccess
}

enum Classification: String {
    case restricted = "35MFYY2JY5.io.keyn.restricted"
    case confidential = "35MFYY2JY5.io.keyn.confidential"
    case secret = "35MFYY2JY5.io.keyn.keyn"
}

class Keychain {
    
    static let shared = Keychain()

    private init() {}

    // MARK: - Unauthenticated Keychain operations
    // These can be synchronous because they never call LocalAuthentication

    func save(id identifier: String, service: String, secretData: Data, objectData: Data? = nil, label: String? = nil, classification: Classification, context: LAContext? = nil) throws {
        var query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrAccount as String: identifier,
                                    kSecAttrService as String: service,
                                    kSecValueData as String: secretData]
        if objectData != nil {
            query[kSecAttrGeneric as String] = objectData
        }
    
        if label != nil {
            query[kSecAttrLabel as String] = label
        }
        
        query[kSecAttrAccessGroup as String] = classification.rawValue

        switch classification {
        case .restricted:
            query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        case .confidential:
            // This will fail if the context is not already authenticated. Use async version of this function to present LocalAuthentication if context is not yet authenticated.
            let access = SecAccessControlCreateWithFlags(nil, // Use the default allocator.
                kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                .userPresence,
                nil) // Ignore any error.
            query[kSecAttrAccessControl as String] = access
            query[kSecUseAuthenticationContext as String] = context ?? LocalAuthenticationManager.shared.mainContext
            query[kSecUseAuthenticationUI as String] = kSecUseAuthenticationUISkip
        case .secret:
            query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        }

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.storeKey
        }
    }

    func get(id identifier: String, service: String, context: LAContext? = nil) throws -> Data {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrAccount as String: identifier,
                                    kSecAttrService as String: service,
                                    kSecMatchLimit as String: kSecMatchLimitOne,
                                    kSecReturnData as String: true,
                                    kSecUseAuthenticationContext as String: context ?? LocalAuthenticationManager.shared.mainContext,
                                    kSecUseAuthenticationUI as String: kSecUseAuthenticationUISkip]

        var queryResult: AnyObject?
        let status = withUnsafeMutablePointer(to: &queryResult) {
            SecItemCopyMatching(query as CFDictionary, UnsafeMutablePointer($0))
        }

        guard status != errSecItemNotFound else { throw KeychainError.notFound }
        guard status == noErr else { throw KeychainError.unhandledError(status) }

        guard let data = queryResult as? Data else {
            throw KeychainError.unexpectedData
        }

        return data
    }

    func has(id identifier: String, service: String) -> Bool {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrAccount as String: identifier,
                                    kSecAttrService as String: service,
                                    kSecMatchLimit as String: kSecMatchLimitOne]

        let status = SecItemCopyMatching(query as CFDictionary, nil)

        return status != errSecItemNotFound
    }

    func update(id identifier: String, service: String, secretData: Data? = nil, objectData: Data? = nil, label: String? = nil, context: LAContext? = nil) throws {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrAccount as String: identifier,
                                    kSecAttrService as String: service,
                                    kSecUseAuthenticationContext as String: context ?? LocalAuthenticationManager.shared.mainContext]

        guard (secretData != nil || label != nil || objectData != nil) else {
            throw KeychainError.noData
        }

        var attributes = [String: Any]()

        if secretData != nil {
            attributes[kSecValueData as String] = secretData
        }

        if objectData != nil {
            attributes[kSecAttrGeneric as String] = objectData
        }

        if label != nil {
            attributes[kSecAttrLabel as String] = label
        }

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        guard status != errSecItemNotFound else { throw KeychainError.notFound }
        guard status == errSecSuccess else { throw KeychainError.unhandledError(status) }
    }
    
    func all(service: String, context: LAContext? = nil) throws -> [[String: Any]]? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service,
                                    kSecMatchLimit as String: kSecMatchLimitAll,
                                    kSecReturnAttributes as String: true,
                                    kSecUseAuthenticationUI as String: kSecUseAuthenticationUIFail,
                                    kSecUseAuthenticationContext as String: context ?? LocalAuthenticationManager.shared.mainContext]

        var queryResult: AnyObject?
        let status = withUnsafeMutablePointer(to: &queryResult) {
            SecItemCopyMatching(query as CFDictionary, UnsafeMutablePointer($0))
        }
        
        if status == errSecItemNotFound {
            return nil
        }

        guard status == noErr else {
            throw KeychainError.unhandledError(status)
        }
        
        guard let dataArray = queryResult as? [[String: Any]] else {
            throw KeychainError.unexpectedData
        }
    
        return dataArray
    }

    func attributes(id identifier: String, service: String, context: LAContext? = nil) throws -> [String: Any]? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrAccount as String: identifier,
                                    kSecAttrService as String: service,
                                    kSecMatchLimit as String: kSecMatchLimitOne,
                                    kSecReturnAttributes as String: true,
                                    kSecUseAuthenticationUI as String: kSecUseAuthenticationUIFail,
                                    kSecUseAuthenticationContext as String: context ?? LocalAuthenticationManager.shared.mainContext]

        var queryResult: AnyObject?
        let status = withUnsafeMutablePointer(to: &queryResult) {
            SecItemCopyMatching(query as CFDictionary, UnsafeMutablePointer($0))
        }

        if status == errSecItemNotFound {
            return nil
        }

        guard status == noErr else {
            throw KeychainError.unhandledError(status)
        }

        guard let dataArray = queryResult as? [String: Any] else {
            throw KeychainError.unexpectedData
        }

        return dataArray
    }


    func delete(id identifier: String, service: String) throws {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrAccount as String: identifier,
                                    kSecAttrService as String: service]

        let status = SecItemDelete(query as CFDictionary)

        guard status != errSecItemNotFound else { throw KeychainError.notFound }
        guard status == errSecSuccess else { throw KeychainError.unhandledError(status) }
    }


    func deleteAll(service: String) {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service]
        SecItemDelete(query as CFDictionary)
    }

    
    // MARK: - Authenticated Keychain operations
    // These operations ask the user to authenticate the operation if necessary. This is handled on a custom OperationQueue that is managed by LocalAuthenticationManager.shared

    func get(id identifier: String, service: String, reason: String, with context: LAContext? = nil, authenticationType type: AuthenticationType, completionHandler: @escaping (_ data: Data?, _ error: Error?) -> Void) {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrAccount as String: identifier,
                                    kSecAttrService as String: service,
                                    kSecMatchLimit as String: kSecMatchLimitOne,
                                    kSecReturnData as String: true,
                                    kSecUseOperationPrompt as String: reason]
        do {
            try LocalAuthenticationManager.shared.execute(query: query, type: type) { (query, _) in
                var queryResult: AnyObject?
                let status = withUnsafeMutablePointer(to: &queryResult) {
                    SecItemCopyMatching(query as CFDictionary, UnsafeMutablePointer($0))
                }

                guard status != errSecItemNotFound else {
                    return completionHandler(nil, KeychainError.notFound)
                }
                guard status == noErr else {
                    return completionHandler(nil, KeychainError.unhandledError(status))
                }
                guard let data = queryResult as? Data else {
                    return completionHandler(nil, KeychainError.unexpectedData)
                }
                completionHandler(data, nil)
            }
        } catch {
            completionHandler(nil, error) // These can be LocalAuthenticationErrors
        }
    }

    func save(id identifier: String, service: String, secretData: Data, objectData: Data? = nil, label: String? = nil, reason: String, authenticationType type: AuthenticationType, with context: LAContext? = nil, completionHandler: @escaping (_ context: LAContext?, _ error: Error?) -> Void) {
        var query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrAccount as String: identifier,
                                    kSecAttrService as String: service,
                                    kSecValueData as String: secretData,
                                    kSecUseOperationPrompt as String: reason]
        if objectData != nil {
            query[kSecAttrGeneric as String] = objectData
        }

        if label != nil {
            query[kSecAttrLabel as String] = label
        }

        guard let access = SecAccessControlCreateWithFlags(nil, kSecAttrAccessibleWhenUnlockedThisDeviceOnly, .userPresence, nil) else {
                return completionHandler(nil, KeychainError.failedCreatingSecAccess)
        } // Ignore any error.
        query[kSecAttrAccessControl as String] = access

        // SecItemAdd does not present LocalAuthentication by itself, so this method is used instead.
        LocalAuthenticationManager.shared.evaluatePolicy(reason: reason, completion: { (context, error) in
            let status = SecItemAdd(query as CFDictionary, nil)
            completionHandler(context, status == errSecSuccess ? nil : KeychainError.storeKey)
        })
    }


    func delete(id identifier: String, service: String, reason: String, authenticationType type: AuthenticationType, with context: LAContext? = nil, completionHandler: @escaping (_ context: LAContext?, _ error: Error?) -> Void) {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrAccount as String: identifier,
                                    kSecAttrService as String: service]

        do {
            try LocalAuthenticationManager.shared.execute(query: query, type: type) { (query, context) in
                let status = SecItemDelete(query as CFDictionary)

                guard status != errSecItemNotFound else {
                    return completionHandler(nil, KeychainError.notFound)
                }
                guard status == errSecSuccess else {
                    return completionHandler(nil, KeychainError.unhandledError(status))
                }
                completionHandler(context, nil)
            }
        } catch {
            completionHandler(nil,error)
        }
    }

    func deleteAll(service: String, reason: String, authenticationType type: AuthenticationType, with context: LAContext? = nil, completionHandler: @escaping (_ error: Error?) -> Void) {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service]

        do {
            try LocalAuthenticationManager.shared.execute(query: query, type: type) { (query, _) in
                let status = SecItemDelete(query as CFDictionary)

                guard status != errSecItemNotFound else {
                    return completionHandler(KeychainError.notFound)
                }
                guard status == errSecSuccess else {
                    return completionHandler(KeychainError.unhandledError(status))
                }
                completionHandler(nil)
            }
        } catch {
            completionHandler(error)
        }
    }

    func update(id identifier: String, service: String, secretData: Data? = nil, objectData: Data? = nil, label: String? = nil, authenticationType type: AuthenticationType, with context: LAContext? = nil, completionHandler: @escaping (_ error: Error?) -> Void) {
        var query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrAccount as String: identifier,
                                    kSecAttrService as String: service]

        guard (secretData != nil || label != nil || objectData != nil) else {
            return completionHandler(KeychainError.noData)
        }

        if let context = context {
            query[kSecUseAuthenticationContext as String] = context
        }

        var attributes = [String: Any]()

        if secretData != nil {
            attributes[kSecValueData as String] = secretData
        }

        if objectData != nil {
            attributes[kSecAttrGeneric as String] = objectData
        }

        if label != nil {
            attributes[kSecAttrLabel as String] = label
        }

        do {
            try LocalAuthenticationManager.shared.execute(query: query, type: type) { (query, _) in
                let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
                guard status != errSecItemNotFound else {
                    return completionHandler(KeychainError.notFound)
                }
                guard status == errSecSuccess else {
                    return completionHandler(KeychainError.unhandledError(status))
                }
                completionHandler(nil)
            }
        } catch {
            completionHandler(error)
        }
    }

    func all(service: String, reason: String, authenticationType type: AuthenticationType, with context: LAContext? = nil, completionHandler: @escaping (_ data: [[String: Any]]?, _ error: Error?) -> Void) {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service,
                                    kSecMatchLimit as String: kSecMatchLimitAll,
                                    kSecReturnAttributes as String: true,
                                    kSecUseOperationPrompt as String: reason]

        do {
            try LocalAuthenticationManager.shared.execute(query: query, type: type) { (query, _) in
                var queryResult: AnyObject?
                let status = withUnsafeMutablePointer(to: &queryResult) {
                    SecItemCopyMatching(query as CFDictionary, UnsafeMutablePointer($0))
                }

                if status == errSecItemNotFound {
                    return completionHandler(nil, nil)
                }

                guard status == noErr else {
                    return completionHandler(nil, KeychainError.unhandledError(status))
                }

                guard let data = queryResult as? [[String: Any]] else {
                    return completionHandler(nil, KeychainError.unexpectedData)
                }

                completionHandler(data, nil)
            }
        } catch {
            completionHandler(nil, error) // These can be LocalAuthenticationErrors
        }
    }

    func attributes(id identifier: String, service: String, reason: String, with context: LAContext? = nil, authenticationType type: AuthenticationType, completionHandler: @escaping (_ data: [String: Any]?, _ context: LAContext?, _ error: Error?) -> Void) {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrAccount as String: identifier,
                                    kSecAttrService as String: service,
                                    kSecMatchLimit as String: kSecMatchLimitOne,
                                    kSecReturnAttributes as String: true,
                                    kSecUseOperationPrompt as String: reason]

        do {
            try LocalAuthenticationManager.shared.execute(query: query, type: type) { (query, context) in
                var queryResult: AnyObject?
                let status = withUnsafeMutablePointer(to: &queryResult) {
                    SecItemCopyMatching(query as CFDictionary, UnsafeMutablePointer($0))
                }

                if status == errSecItemNotFound {
                    return completionHandler(nil, nil, nil)
                }

                guard status == noErr else {
                    return completionHandler(nil, nil, KeychainError.unhandledError(status))
                }

                guard let data = queryResult as? [String: Any] else {
                    return completionHandler(nil, nil, KeychainError.unexpectedData)
                }

                completionHandler(data, context, nil)
            }
        } catch {
            completionHandler(nil, nil, error) // These can be LocalAuthenticationErrors
        }
    }

}
