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
    case authenticationCancelled
}

enum KeychainService: String {
    case account = "io.keyn.account"
    case sharedAccount = "io.keyn.sharedaccount"
    case otp = "io.keyn.otp"
    case webauthn = "io.keyn.webauthn"
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
        case .seed, .otp:
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

class Keychain {
    
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

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unhandledError(status)
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
        let status = withUnsafeMutablePointer(to: &queryResult) {
            SecItemCopyMatching(query as CFDictionary, UnsafeMutablePointer($0))
        }

        guard status != errSecInteractionNotAllowed else { throw KeychainError.interactionNotAllowed }
        guard status != errSecItemNotFound else { return nil }
        guard status == noErr else { throw KeychainError.unhandledError(status) }
        if queryResult == nil {
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

        let status = SecItemCopyMatching(query as CFDictionary, nil)

        return status != errSecItemNotFound
    }

    func update(id identifier: String, service: KeychainService, secretData: Data? = nil, objectData: Data? = nil, context: LAContext? = nil) throws {
        var query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrAccount as String: identifier,
                                    kSecAttrService as String: service.rawValue,
                                    kSecUseAuthenticationUI as String: kSecUseAuthenticationUIFail]

        if let defaultContext = service.defaultContext {
            query[kSecUseAuthenticationContext as String] = context ?? defaultContext
        }

        guard (secretData != nil || objectData != nil) else {
            throw KeychainError.noData
        }

        var attributes = [String: Any]()

        if secretData != nil {
            attributes[kSecValueData as String] = secretData
        }

        if objectData != nil {
            attributes[kSecAttrGeneric as String] = objectData
        }

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        guard status != errSecItemNotFound else { throw KeychainError.notFound }
        guard status == errSecSuccess else { throw KeychainError.unhandledError(status) }
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
        let status = withUnsafeMutablePointer(to: &queryResult) {
            SecItemCopyMatching(query as CFDictionary, UnsafeMutablePointer($0))
        }
        
        if status == errSecItemNotFound {
            return nil
        }
        if status == -26276 || status == errSecInteractionNotAllowed {
            throw KeychainError.interactionNotAllowed
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

        guard status != errSecInteractionNotAllowed else {
            throw KeychainError.interactionNotAllowed
        }

        guard status == noErr else {
            throw KeychainError.unhandledError(status)
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

        let status = SecItemDelete(query as CFDictionary)

        guard status != errSecItemNotFound else { throw KeychainError.notFound }
        guard status == errSecSuccess else { throw KeychainError.unhandledError(status) }
    }

    func deleteAll(service: KeychainService, label: String? = nil) {
        var query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service.rawValue]
        if let label = label {
            query[kSecAttrLabel as String] = label
        }
        SecItemDelete(query as CFDictionary)
    }

    func isSynced(id identifier: String, service: KeychainService) throws -> Bool {
        var query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrAccount as String: identifier,
                                    kSecAttrService as String: service.rawValue,
                                    kSecMatchLimit as String: kSecMatchLimitOne,
                                    kSecReturnAttributes as String: true,
                                    kSecUseAuthenticationUI as String: kSecUseAuthenticationUIFail]

        if let defaultContext = service.defaultContext {
            query[kSecUseAuthenticationContext as String] = defaultContext
        }

        var queryResult: AnyObject?
        let status = withUnsafeMutablePointer(to: &queryResult) {
            SecItemCopyMatching(query as CFDictionary, UnsafeMutablePointer($0))
        }

        guard status != errSecInteractionNotAllowed else { throw KeychainError.interactionNotAllowed }
        guard status != errSecItemNotFound else { throw KeychainError.notFound }
        guard status == noErr else { throw KeychainError.unhandledError(status) }

        guard let dataArray = queryResult as? [String: Any] else {
            throw KeychainError.unexpectedData
        }

        if let label = dataArray[kSecAttrType as String] as? String {
            return label == "true"
        } else { // Not present, we'll assume it's synced
            try setSynced(value: true, id: identifier, service: service)
            return true
        }
    }

    func setSynced(value: Bool, id identifier: String, service: KeychainService) throws {
        var query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrAccount as String: identifier,
                                    kSecAttrService as String: service.rawValue,
                                    kSecUseAuthenticationUI as String: kSecUseAuthenticationUIFail]

        if let defaultContext = service.defaultContext {
            query[kSecUseAuthenticationContext as String] = defaultContext
        }

        let attributes: [String: Any] = [kSecAttrType as String: value ? "true" : "fals"] // Four characters

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        guard status != errSecItemNotFound else { throw KeychainError.notFound }
        guard status == errSecSuccess else { throw KeychainError.unhandledError(status) }
    }

    // MARK: - Authenticated Keychain operations
    // These operations ask the user to authenticate the operation if necessary. This is handled on a custom OperationQueue that is managed by LocalAuthenticationManager.shared

    func get(id identifier: String, service: KeychainService, reason: String, with context: LAContext? = nil, authenticationType type: AuthenticationType, completionHandler: @escaping (Result<Data?, Error>) -> Void) {
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
                    return completionHandler(.success(nil))
                }
                guard status == noErr else {
                    return completionHandler(.failure(KeychainError.unhandledError(status)))
                }
                if queryResult == nil {
                    return completionHandler(.success(nil))
                }
                guard let data = queryResult as? Data else {
                    return completionHandler(.failure(KeychainError.unexpectedData))
                }
                completionHandler(.success(data))
            }
        } catch {
            completionHandler(.failure(error)) // These can be LocalAuthenticationErrors
        }
    }

    func delete(id identifier: String, service: KeychainService, reason: String, authenticationType type: AuthenticationType, with context: LAContext? = nil, completionHandler: @escaping (Result<LAContext, Error>) -> Void) {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrAccount as String: identifier,
                                    kSecAttrService as String: service.rawValue]

        do {
            try LocalAuthenticationManager.shared.execute(query: query, type: type) { (query, context) in
                let status = SecItemDelete(query as CFDictionary)

                guard status != errSecItemNotFound else {
                    return completionHandler(.failure(KeychainError.notFound))
                }
                guard status == errSecSuccess else {
                    return completionHandler(.failure(KeychainError.unhandledError(status)))
                }
                completionHandler(.success(context))
            }
        } catch {
            completionHandler(.failure(error))
        }
    }

}
