import Foundation
import Security


enum KeychainError: Error {
    case stringEncoding
    case storeKey
    case notFound
    case unexpectedData
    case unhandledError(status: OSStatus)
}


class Keychain {

    // MARK: Password operations

    class func savePassword(_ password: String, with identifier: String) throws {
        guard let passwordData = password.data(using: .utf8) else {
            throw KeychainError.stringEncoding
        }

        let query: [String: Any] = [kSecClass as String: kSecClassInternetPassword,
                                       kSecAttrAccount as String: identifier,
                                       kSecValueData as String: passwordData]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.storeKey }

    }

    class func getPassword(with identifier: String) throws -> String {
        let query: [String: Any] = [kSecClass as String: kSecClassInternetPassword,
                                    kSecAttrAccount as String: identifier,
                                    kSecMatchLimit as String: kSecMatchLimitOne,
                                    kSecReturnData as String: true]

        // Try to fetch the data if it exists.
        var queryResult: AnyObject?
        let status = withUnsafeMutablePointer(to: &queryResult) {
            SecItemCopyMatching(query as CFDictionary, UnsafeMutablePointer($0))
        }

        // Check the return status and throw an error if appropriate.
        guard status != errSecItemNotFound else { throw KeychainError.notFound }
        guard status == noErr else { throw KeychainError.unhandledError(status: status) }

        guard let data = queryResult as? Data, let password = String(data: data, encoding: .utf8) else {
            throw KeychainError.unexpectedData
        }

        return password
    }

    class func updatePassword(_ newPassword: String, with identifier: String) throws {
        guard let passwordData = newPassword.data(using: .utf8) else {
            throw KeychainError.stringEncoding
        }

        let query: [String: Any] = [kSecClass as String: kSecClassInternetPassword,
                                    kSecAttrAccount as String: identifier,
                                    kSecMatchLimit as String: kSecMatchLimitOne]

        let attributes: [String: Any] = [kSecValueData as String: passwordData]

        // Try to fetch the data if it exists.
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        // Check the return status and throw an error if appropriate.
        guard status != errSecItemNotFound else { throw KeychainError.notFound }
        guard status == errSecSuccess else { throw KeychainError.unhandledError(status: status) }
    }

    class func deletePassword(with identifier: String) throws {
        let query: [String: Any] = [kSecClass as String: kSecClassInternetPassword,
                                    kSecAttrAccount as String: identifier,
                                    kSecMatchLimit as String: kSecMatchLimitOne]

        // Try to fetch the data if it exists.
        let status = SecItemDelete(query as CFDictionary)

        // Check the return status and throw an error if appropriate.
        guard status != errSecItemNotFound else { throw KeychainError.notFound }
        guard status == errSecSuccess else { throw KeychainError.unhandledError(status: status) }
    }


    // MARK: Seed operations

    class func saveSeed(seed: Data) throws {
        let tag = "com.athena.seed" // TODO: Check what is the best identifier for the seed.
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                       kSecAttrAccount as String: tag,
                                       kSecValueData as String: seed]

        // Try to add the session key to the keychain.
        let status = SecItemAdd(query as CFDictionary, nil)

        // Check the return status and throw an error if appropriate.
        guard status == errSecSuccess else { throw KeychainError.storeKey }
    }

    class func getSeed() throws -> Data {
        let tag = "com.athena.seed"
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrAccount as String: tag,
                                    kSecMatchLimit as String: kSecMatchLimitOne,
                                    kSecReturnData as String: true]

        // Try to fetch the seed if it exists.
        var queryResult: AnyObject?
        let status = withUnsafeMutablePointer(to: &queryResult) {
            SecItemCopyMatching(query as CFDictionary, UnsafeMutablePointer($0))
        }

        // Check the return status and throw an error if appropriate.
        guard status != errSecItemNotFound else { throw KeychainError.notFound }
        guard status == noErr else { throw KeychainError.unhandledError(status: status) }
        guard let data = queryResult as? Data else { throw KeychainError.unexpectedData }

        return data
    }

    class func hasSeed() -> Bool {
        let tag = "com.athena.seed"
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrAccount as String: tag,
                                    kSecMatchLimit as String: kSecMatchLimitOne]

        // Try to check if the seed exists.
        var queryResult: AnyObject?
        let status = withUnsafeMutablePointer(to: &queryResult) {
            SecItemCopyMatching(query as CFDictionary, UnsafeMutablePointer($0))
        }

        return status != errSecItemNotFound
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
            throw KeychainError.storeKey
        }

    }


    // Maybe this function will never be needed since public keys are only set, used directly and deleted
    class func getSessionKey(with identifier: String) throws -> SecKey {
        let tag = "com.athena.keys.\(identifier)".data(using: .utf8)!
        let query: [String: Any] = [kSecClass as String: kSecClassKey,
                                    kSecAttrApplicationTag as String: tag,
                                    kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
                                    kSecReturnRef as String: true]

        // Try to fetch the session key if it exists.
        var queryResult: AnyObject?
        let status = withUnsafeMutablePointer(to: &queryResult) {
            SecItemCopyMatching(query as CFDictionary, UnsafeMutablePointer($0))
        }

        // Check the return status and throw an error if appropriate.
        guard status != errSecItemNotFound else { throw KeychainError.notFound }
        guard status == noErr else { throw KeychainError.unhandledError(status: status) }
        let pubKey = queryResult as! SecKey

        return pubKey
    }


    class func removeSessionKey(with identifier: String) throws {
        let tag = "com.athena.keys.\(identifier)".data(using: .utf8)!

        let query: [String: Any] = [kSecClass as String: kSecClassKey,
                                    kSecAttrApplicationTag as String: tag,
                                    kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom]

        // Try to delete the session key if it exists.
        let status = SecItemDelete(query as CFDictionary)

        // Check the return status and throw an error if appropriate.
        guard status != errSecItemNotFound else { throw KeychainError.notFound }
        guard status == errSecSuccess else { throw KeychainError.unhandledError(status: status) }
    }

}
