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

enum KeychainService: String {
    case account = "io.keyn.account"
    case otp = "io.keyn.otp"
    case seed = "io.keyn.seed"
    case sharedSessionKey = "io.keyn.session.shared"
    case signingSessionKey = "io.keyn.session.signing"
    case aws = "io.keyn.aws"
    case backup = "io.keyn.backup"

    var classification: Classification {
        switch self {
        case .account:
            return .confidential
        case .otp, .seed, .aws, .backup:
            return .secret
        case .sharedSessionKey, .signingSessionKey:
            return .restricted
        }
    }

    var defaultContext: LAContext? {
        return self.classification == .confidential ? LocalAuthenticationManager.shared.mainContext : nil
    }

    enum Classification: String {
        case restricted = "35MFYY2JY5.io.keyn.restricted"
        case confidential = "35MFYY2JY5.io.keyn.confidential"
        case secret = "35MFYY2JY5.io.keyn.keyn"
    }
}

class Keychain {
    
    static let shared = Keychain()

    private init() {}

    // MARK: - Unauthenticated Keychain operations
    // These can be synchronous because they never call LocalAuthentication

    func save(id identifier: String, service: KeychainService, secretData: Data, objectData: Data? = nil, label: String? = nil) throws {
        var query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrAccount as String: identifier,
                                    kSecAttrService as String: service.rawValue,
                                    kSecValueData as String: secretData]
        if objectData != nil {
            query[kSecAttrGeneric as String] = objectData
        }
    
        if label != nil {
            query[kSecAttrLabel as String] = label
        }
        
        query[kSecAttrAccessGroup as String] = service.classification

        switch service.classification {
        case .restricted:
            query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        case .confidential:
            Logger.shared.warning("Confidential Keychain items shouldn't be stored with the Keychain.save sync operation.")
            // This will fail if the context is not already authenticated. Use async version of this function to present LocalAuthentication if context is not yet authenticated.
            let access = SecAccessControlCreateWithFlags(nil, // Use the default allocator.
                kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                .userPresence,
                nil) // Ignore any error.
            query[kSecAttrAccessControl as String] = access
        case .secret:
            query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        }

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.storeKey
        }
    }

    func get(id identifier: String, service: KeychainService, context: LAContext? = nil) throws -> Data {
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

    func has(id identifier: String, service: KeychainService, context: LAContext? = nil) -> Bool {
        var query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrAccount as String: identifier,
                                    kSecAttrService as String: service.rawValue,
                                    kSecMatchLimit as String: kSecMatchLimitOne,
                                    kSecUseAuthenticationUI as String: kSecUseAuthenticationUIFail]

        if let defaultContext = service.defaultContext {
            query[kSecUseAuthenticationContext as String] = context ?? defaultContext
        }

        let status = SecItemCopyMatching(query as CFDictionary, nil)

        return status != errSecItemNotFound
    }

    func update(id identifier: String, service: KeychainService, secretData: Data? = nil, objectData: Data? = nil, label: String? = nil, context: LAContext? = nil) throws {
        var query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrAccount as String: identifier,
                                    kSecAttrService as String: service.rawValue,
                                    kSecUseAuthenticationUI as String: kSecUseAuthenticationUIFail]

        if let defaultContext = service.defaultContext {
            query[kSecUseAuthenticationContext as String] = context ?? defaultContext
        }

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
    
    func all(service: KeychainService, context: LAContext? = nil) throws -> [[String: Any]]? {
        var query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service.rawValue,
                                    kSecMatchLimit as String: kSecMatchLimitAll,
                                    kSecReturnAttributes as String: true,
                                    kSecUseAuthenticationUI as String: kSecUseAuthenticationUIFail]

        if let defaultContext = service.defaultContext {
            query[kSecUseAuthenticationContext as String] = context ?? defaultContext
        }

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

    #warning("TODO: Check if these need a context for sync operations")
    func delete(id identifier: String, service: KeychainService) throws {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrAccount as String: identifier,
                                    kSecAttrService as String: service.rawValue]

        let status = SecItemDelete(query as CFDictionary)

        guard status != errSecItemNotFound else { throw KeychainError.notFound }
        guard status == errSecSuccess else { throw KeychainError.unhandledError(status) }
    }

    #warning("TODO: Check if these need a context for sync operations")
    func deleteAll(service: KeychainService) {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service.rawValue]
        SecItemDelete(query as CFDictionary)
    }

    
    // MARK: - Authenticated Keychain operations
    // These operations ask the user to authenticate the operation if necessary. This is handled on a custom OperationQueue that is managed by LocalAuthenticationManager.shared

    func get(id identifier: String, service: KeychainService, reason: String, with context: LAContext? = nil, authenticationType type: AuthenticationType, completionHandler: @escaping (_ data: Data?, _ error: Error?) -> Void) {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrAccount as String: identifier,
                                    kSecAttrService as String: service.rawValue,
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

    func save(id identifier: String, service: KeychainService, secretData: Data, objectData: Data? = nil, label: String? = nil, reason: String, authenticationType type: AuthenticationType, with context: LAContext? = nil, completionHandler: @escaping (_ context: LAContext?, _ error: Error?) -> Void) {
        var query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrAccount as String: identifier,
                                    kSecAttrService as String: service.rawValue,
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


    func delete(id identifier: String, service: KeychainService, reason: String, authenticationType type: AuthenticationType, with context: LAContext? = nil, completionHandler: @escaping (_ context: LAContext?, _ error: Error?) -> Void) {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrAccount as String: identifier,
                                    kSecAttrService as String: service.rawValue]

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

    func deleteAll(service: KeychainService, reason: String, authenticationType type: AuthenticationType, with context: LAContext? = nil, completionHandler: @escaping (_ error: Error?) -> Void) {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service.rawValue]

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

    func update(id identifier: String, service: KeychainService, secretData: Data? = nil, objectData: Data? = nil, label: String? = nil, authenticationType type: AuthenticationType, with context: LAContext? = nil, completionHandler: @escaping (_ error: Error?) -> Void) {
        var query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrAccount as String: identifier,
                                    kSecAttrService as String: service.rawValue]

        guard (secretData != nil || label != nil || objectData != nil) else {
            return completionHandler(KeychainError.noData)
        }

        if let defaultContext = service.defaultContext {
            query[kSecUseAuthenticationContext as String] = context ?? defaultContext
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

    func all(service: KeychainService, reason: String, authenticationType type: AuthenticationType, with context: LAContext? = nil, completionHandler: @escaping (_ data: [[String: Any]]?, _ error: Error?) -> Void) {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service.rawValue,
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

    func attributes(id identifier: String, service: KeychainService, reason: String, with context: LAContext? = nil, authenticationType type: AuthenticationType, completionHandler: @escaping (_ data: [String: Any]?, _ context: LAContext?, _ error: Error?) -> Void) {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrAccount as String: identifier,
                                    kSecAttrService as String: service.rawValue,
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
