/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import Foundation
import Security

struct KeychainError: KeynError {
    enum ErrorKind: String {
        case stringEncoding
        case unexpectedData
        case storeKey
        case notFound
        case unhandledError
        case noData
        case interactionNotAllowed
    }
    
    let kind: ErrorKind
    let status: OSStatus?
    var nsError: NSError {
        return NSError(domain: "ViaVia.KeychainError", code: 0, userInfo: ["OSStatus": status ?? 0, "error_type": kind.rawValue ])
    }
}

enum Classification: String {
    case restricted = "35MFYY2JY5.io.keyn.restricted"
    case confidential = "35MFYY2JY5.io.keyn.confidential"
    case secret = "35MFYY2JY5.io.keyn.keyn"
}

class Keychain {
    static let shared = Keychain()
    
    private init() {}
    
    // MARK: - CRUD methods

    func save(secretData: Data, id identifier: String, service: String, objectData: Data? = nil, label: String? = nil, classification: Classification) throws {
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
            query[kSecAttrAccessible as String] = kSecAttrAccessibleAlwaysThisDeviceOnly
        case .confidential:
            query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        case .secret:
            query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        }

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError(kind: .storeKey, status: status)
        }
    }

    func get(id identifier: String, service: String) throws -> Data {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrAccount as String: identifier,
                                    kSecAttrService as String: service,
                                    kSecMatchLimit as String: kSecMatchLimitOne,
                                    kSecReturnData as String: true]

        var queryResult: AnyObject?
        let status = withUnsafeMutablePointer(to: &queryResult) {
            SecItemCopyMatching(query as CFDictionary, UnsafeMutablePointer($0))
        }

        guard status != errSecItemNotFound else { throw KeychainError(kind: .notFound, status: status) }
        guard status == noErr else { throw KeychainError(kind: .unhandledError, status: status) }

        guard let data = queryResult as? Data else {
            throw KeychainError(kind: .unexpectedData, status: status)
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

    func delete(id identifier: String, service: String) throws {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrAccount as String: identifier,
                                    kSecAttrService as String: service]

        let status = SecItemDelete(query as CFDictionary)

        guard status != errSecItemNotFound else { throw KeychainError(kind: .notFound, status: status) }
        guard status == errSecSuccess else { throw KeychainError(kind: .unhandledError, status: status) }
    }

    func update(id identifier: String, service: String, secretData: Data? = nil, objectData: Data? = nil, label: String? = nil) throws {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrAccount as String: identifier,
                                    kSecAttrService as String: service]

        guard (secretData != nil || label != nil || objectData != nil) else {
            throw KeychainError(kind: .noData, status: nil)
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

        guard status != errSecItemNotFound else { throw KeychainError(kind: .notFound, status: status) }
        guard status == errSecSuccess else { throw KeychainError(kind: .unhandledError, status: status) }
    }
    
    func all(service: String) throws -> [[String: Any]]? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service,
                                    kSecMatchLimit as String: kSecMatchLimitAll,
                                    kSecReturnAttributes as String: true]
        
        var queryResult: AnyObject?
        let status = withUnsafeMutablePointer(to: &queryResult) {
            SecItemCopyMatching(query as CFDictionary, UnsafeMutablePointer($0))
        }
        
        if status == errSecItemNotFound {
            return nil
        }

        guard status == noErr else {
            throw KeychainError(kind: .unhandledError, status: status)
        }
        
        guard let dataArray = queryResult as? [[String: Any]] else {
            throw KeychainError(kind: .unexpectedData, status: status)
        }
    
        return dataArray
    }

    func attributes(id identifier: String, service: String) throws -> [String: Any]? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrAccount as String: identifier,
                                    kSecAttrService as String: service,
                                    kSecMatchLimit as String: kSecMatchLimitOne,
                                    kSecReturnAttributes as String: true]

        var queryResult: AnyObject?
        let status = withUnsafeMutablePointer(to: &queryResult) {
            SecItemCopyMatching(query as CFDictionary, UnsafeMutablePointer($0))
        }

        if status == errSecItemNotFound {
            return nil
        }

        guard status == noErr else {
            throw KeychainError(kind: .unhandledError, status: status)
        }

        guard let dataArray = queryResult as? [String: Any] else {
            throw KeychainError(kind: .unexpectedData, status: status)
        }

        return dataArray
    }

    func deleteAll(service: String) {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service]
        SecItemDelete(query as CFDictionary)
    }
}
