import Foundation
import Security


enum KeychainError: Error {
    case stringEncoding
    case unexpectedData
    case storeKey(OSStatus?)
    case notFound(OSStatus?)
    case unhandledError(OSStatus?)
    case noData
}


class Keychain {
    
    static let sharedInstance = Keychain()
    
    private init() {} //This prevents others from using the default '()' initializer for this singleton class.

    // TODO: Add accessability restrictions

    // MARK:  CRUD methods

   func save(secretData: Data, id identifier: String, service: String, objectData: Data? = nil) throws {
        var query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrAccount as String: identifier,
                                    kSecAttrService as String: service,
                                    kSecValueData as String: secretData]
        if objectData != nil {
            query[kSecAttrGeneric as String] = objectData
        }

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.storeKey(status) }

    }

    func get(id identifier: String, service: String) throws -> Data {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrAccount as String: identifier,
                                    kSecAttrService as String: service,
                                    kSecMatchLimit as String: kSecMatchLimitOne,
                                    kSecReturnData as String: true]

        // Try to fetch the data if it exists.
        var queryResult: AnyObject?
        let status = withUnsafeMutablePointer(to: &queryResult) {
            SecItemCopyMatching(query as CFDictionary, UnsafeMutablePointer($0))
        }

        // Check the return status and throw an error if appropriate.
        guard status != errSecItemNotFound else { throw KeychainError.notFound(status) }
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

        // Try to check if the seed exists.
        let status = SecItemCopyMatching(query as CFDictionary, nil)

        return status != errSecItemNotFound
    }

    func delete(id identifier: String, service: String) throws {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrAccount as String: identifier,
                                    kSecAttrService as String: service]

        // Try to fetch the data if it exists.
        let status = SecItemDelete(query as CFDictionary)

        // Check the return status and throw an error if appropriate.
        guard status != errSecItemNotFound else { throw KeychainError.notFound(status) }
        guard status == errSecSuccess else { throw KeychainError.unhandledError(status) }
    }

    func update(id identifier: String, service: String, secretData: Data?, objectData: Data?, label: String?) throws {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrAccount as String: identifier,
                                    kSecAttrService as String: service]

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

        // Check the return status and throw an error if appropriate.
        guard status != errSecItemNotFound else { throw KeychainError.notFound(status) }
        guard status == errSecSuccess else { throw KeychainError.unhandledError(status) }
    }

    
    func all(service: String) throws -> [[String: Any]]? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service,
                                    kSecMatchLimit as String: kSecMatchLimitAll,
                                    kSecReturnAttributes as String: true]
        
        // Try to fetch the data if it exists.
        var queryResult: AnyObject?
        let status = withUnsafeMutablePointer(to: &queryResult) {
            SecItemCopyMatching(query as CFDictionary, UnsafeMutablePointer($0))
        }
        
        // Check the return status and throw an error if appropriate.
        if status == errSecItemNotFound {
            // No stored sessions found, return nil
            return nil
        }
        guard status == noErr else { throw KeychainError.unhandledError(status) }
        
        guard let dataArray = queryResult as? [[String: Any]] else {
            throw KeychainError.unexpectedData
        }
    
        return dataArray
    }


    func attributes(id identifier: String, service: String) throws -> [String: Any]? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrAccount as String: identifier,
                                    kSecAttrService as String: service,
                                    kSecMatchLimit as String: kSecMatchLimitOne,
                                    kSecReturnAttributes as String: true]

        // Try to fetch the data if it exists.
        var queryResult: AnyObject?
        let status = withUnsafeMutablePointer(to: &queryResult) {
            SecItemCopyMatching(query as CFDictionary, UnsafeMutablePointer($0))
        }

        // Check the return status and throw an error if appropriate.
        if status == errSecItemNotFound {
            // No attributes found, return nil
            return nil
        }
        guard status == noErr else { throw KeychainError.unhandledError(status) }

        guard let dataArray = queryResult as? [String: Any] else {
            throw KeychainError.unexpectedData
        }

        return dataArray
    }

}
