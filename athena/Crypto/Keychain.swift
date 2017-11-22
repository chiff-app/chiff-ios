import Foundation
import Security


enum KeychainError: Error {
    case stringEncoding
    case unexpectedData
    case storeKey(OSStatus?)
    case notFound(OSStatus?)
    case unhandledError(OSStatus?)
}


class Keychain {

    static let passwordService = "com.athena.password"
    static let seedService = "com.athena.seed"


    // MARK: Password operations

    class func savePassword(_ password: String, with identifier: String) throws {
        guard let passwordData = password.data(using: .utf8) else {
            throw KeychainError.stringEncoding
        }
        try setData(passwordData, with: identifier, service: passwordService)
    }

    class func getPassword(with identifier: String) throws -> String {
        let data = try getData(with: identifier, service: passwordService)
        
        guard let password = String(data: data, encoding: .utf8) else {
            throw KeychainError.unexpectedData
        }

        return password
    }

    class func updatePassword(_ newPassword: String, with identifier: String) throws {
        guard let passwordData = newPassword.data(using: .utf8) else {
            throw KeychainError.stringEncoding
        }
        try updateData(passwordData, with: identifier, service: passwordService)
    }

    class func deletePassword(with identifier: String) throws {
        try deleteData(with: identifier, service: passwordService)
    }


    // MARK: Seed operations

    class func saveSeed(seed: Data) throws {
        try setData(seed, with: seedService, service: seedService)
    }

    class func getSeed() throws -> Data {
        return try getData(with: seedService, service: seedService)
    }

    class func hasSeed() -> Bool {
        return hasData(with: seedService, service: seedService)
    }

    class func deleteSeed() throws {
        try deleteData(with: seedService, service: seedService)
    }


    // MARK: Session key operations

    class func saveSessionKey(_ key: SecKey, with identifier: String) throws {
        let tag = "com.athena.keys.\(identifier)".data(using: .utf8)!
        let query: [String: Any] = [kSecClass as String: kSecClassKey,
                                    kSecAttrApplicationTag as String: tag,
                                    kSecValueRef as String: key]

        // Try to add the session key to the keychain.
        let status = SecItemAdd(query as CFDictionary, nil)

        // Check the return status and throw an error if appropriate.
        guard status == errSecSuccess else {
            throw KeychainError.storeKey(status)
        }

    }


    // Maybe this function will never be needed since public keys are only set, used directly and deleted
    class func getSessionKey(with identifier: String) throws -> SecKey {
        let tag = "com.athena.keys.\(identifier)".data(using: .utf8)!
        let query: [String: Any] = [kSecClass as String: kSecClassKey,
                                    kSecAttrApplicationTag as String: tag,
                                    kSecReturnRef as String: true]

        // Try to fetch the session key if it exists.
        var queryResult: AnyObject?
        let status = withUnsafeMutablePointer(to: &queryResult) {
            SecItemCopyMatching(query as CFDictionary, UnsafeMutablePointer($0))
        }

        // Check the return status and throw an error if appropriate.
        guard status != errSecItemNotFound else { throw KeychainError.notFound(status) }
        guard status == noErr else { throw KeychainError.unhandledError(status) }
        let pubKey = queryResult as! SecKey

        return pubKey
    }


    class func removeSessionKey(with identifier: String) throws {
        let tag = "com.athena.keys.\(identifier)".data(using: .utf8)!

        let query: [String: Any] = [kSecClass as String: kSecClassKey,
                                    kSecAttrApplicationTag as String: tag]

        // Try to delete the session key if it exists.
        let status = SecItemDelete(query as CFDictionary)

        // Check the return status and throw an error if appropriate.
        guard status != errSecItemNotFound else { throw KeychainError.notFound(status) }
        guard status == errSecSuccess else { throw KeychainError.unhandledError(status) }
    }


    // MARK: Private CRUD methods

    private class func setData(_ data: Data, with identifier: String, service: String) throws {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrAccount as String: identifier,
                                    kSecAttrService as String: service,
                                    kSecValueData as String: data]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.storeKey(status) }

    }

    private class func getData(with identifier: String, service: String) throws -> Data {
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

    private class func hasData(with identifier: String, service: String) -> Bool {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrAccount as String: identifier,
                                    kSecAttrService as String: service,
                                    kSecMatchLimit as String: kSecMatchLimitOne]

        // Try to check if the seed exists.
        let status = SecItemCopyMatching(query as CFDictionary, nil)

        return status != errSecItemNotFound
    }

    private class func deleteData(with identifier: String, service: String) throws {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrAccount as String: identifier,
                                    kSecAttrService as String: service,
                                    kSecMatchLimit as String: kSecMatchLimitOne]

        // Try to fetch the data if it exists.
        let status = SecItemDelete(query as CFDictionary)

        // Check the return status and throw an error if appropriate.
        guard status != errSecItemNotFound else { throw KeychainError.notFound(status) }
        guard status == errSecSuccess else { throw KeychainError.unhandledError(status) }
    }

    private class func updateData(_ data: Data, with identifier: String, service: String) throws {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrAccount as String: identifier,
                                    kSecAttrService as String: service,
                                    kSecMatchLimit as String: kSecMatchLimitOne]

        let attributes: [String: Any] = [kSecValueData as String: data]

        // Try to fetch the data if it exists.
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        // Check the return status and throw an error if appropriate.
        guard status != errSecItemNotFound else { throw KeychainError.notFound(status) }
        guard status == errSecSuccess else { throw KeychainError.unhandledError(status) }
    }

}
