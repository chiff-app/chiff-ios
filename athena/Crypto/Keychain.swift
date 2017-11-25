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
    
    static let sharedInstance = Keychain()
    static let passwordService = "com.athena.password"
    static let seedService = "com.athena.seed"
    static let sessionBrowserService = "com.athena.session.browser"
    static let sessionAppService = "com.athena.session"
    
    private init() {} //This prevents others from using the default '()' initializer for this singleton class.

    // TODO: Add accessability restrictions

    // MARK: Password operations

    func savePassword(_ password: String, account: Data, with identifier: String) throws {
        guard let passwordData = password.data(using: .utf8) else {
            throw KeychainError.stringEncoding
        }
        try Keychain.sharedInstance.setData(passwordData, with: identifier, service: Keychain.passwordService, attributes: account)
    }

    func getPassword(with identifier: String) throws -> String {
        let data = try getData(with: identifier, service: Keychain.passwordService)
        
        guard let password = String(data: data, encoding: .utf8) else {
            throw KeychainError.unexpectedData
        }

        return password
    }

    func updatePassword(_ newPassword: String, with identifier: String) throws {
        guard let passwordData = newPassword.data(using: .utf8) else {
            throw KeychainError.stringEncoding
        }
        try updateData(passwordData, with: identifier, service: Keychain.passwordService)
    }

    func deletePassword(with identifier: String) throws {
        try deleteData(with: identifier, service: Keychain.passwordService)
    }

    func getAllSessions() throws -> [Session] {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: Keychain.sessionBrowserService,
                                    kSecMatchLimit as String: kSecMatchLimitAll,
                                    kSecReturnAttributes as String: true]

        // Try to fetch the data if it exists.
        var queryResult: AnyObject?
        let status = withUnsafeMutablePointer(to: &queryResult) {
            SecItemCopyMatching(query as CFDictionary, UnsafeMutablePointer($0))
        }

        // Check the return status and throw an error if appropriate.
        guard status != errSecItemNotFound else { throw KeychainError.notFound(status) }
        guard status == noErr else { throw KeychainError.unhandledError(status) }

        guard let dataArray = queryResult as? [[String: Any]] else {
            throw KeychainError.unexpectedData
        }

        var sessions = [Session]()
        let decoder = PropertyListDecoder()

        for dict in dataArray {
            guard let sessionData = dict[kSecAttrGeneric as String] as? Data else {
                throw KeychainError.unexpectedData
            }
            sessions.append(try decoder.decode(Session.self, from: sessionData))
        }
        return sessions
    }

    func getAllAccounts() throws -> [Account] {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: Keychain.passwordService,
                                    kSecMatchLimit as String: kSecMatchLimitAll,
                                    kSecReturnAttributes as String: true]

        // Try to fetch the data if it exists.
        var queryResult: AnyObject?
        let status = withUnsafeMutablePointer(to: &queryResult) {
            SecItemCopyMatching(query as CFDictionary, UnsafeMutablePointer($0))
        }

        // Check the return status and throw an error if appropriate.
        guard status != errSecItemNotFound else { throw KeychainError.notFound(status) }
        guard status == noErr else { throw KeychainError.unhandledError(status) }

        guard let dataArray = queryResult as? [[String: Any]] else {
            throw KeychainError.unexpectedData
        }

        var accounts = [Account]()
        let decoder = PropertyListDecoder()

        for dict in dataArray {
            guard let accountData = dict[kSecAttrGeneric as String] as? Data else {
                throw KeychainError.unexpectedData
            }
            accounts.append(try decoder.decode(Account.self, from: accountData))
        }
        return accounts
    }


    // MARK: Seed operations

    func saveSeed(seed: Data) throws {
        try setData(seed, with: Keychain.seedService, service: Keychain.seedService, attributes: nil)
    }

    func getSeed() throws -> Data {
        return try getData(with: Keychain.seedService, service: Keychain.seedService)
    }

    func hasSeed() -> Bool {
        return hasData(with: Keychain.seedService, service: Keychain.seedService)
    }

    func deleteSeed() throws {
        try deleteData(with: Keychain.seedService, service: Keychain.seedService)
    }


    // MARK: Session key operations

    func saveBrowserSessionKey(_ keyData: Data, with identifier: String, attributes: Data) throws {
        try setData(keyData, with: identifier, service: Keychain.sessionBrowserService, attributes: attributes)
    }

    func saveAppSessionKey(_ keyData: Data, with identifier: String) throws {
        try setData(keyData, with: identifier, service: Keychain.sessionAppService, attributes: nil)
    }

    func getBrowserSessionKey(with identifier: String) throws -> Data {
        return try getData(with: identifier, service: Keychain.sessionBrowserService)
    }

    func getAppSessionKey(with identifier: String) throws -> Data {
        return try getData(with: identifier, service: Keychain.sessionAppService)
    }

    func removeBrowserSessionKey(with identifier: String) throws {
        try deleteData(with: identifier, service: Keychain.sessionBrowserService)
    }

    func removeAppSessionKey(with identifier: String) throws {
        try deleteData(with: identifier, service: Keychain.sessionAppService)
    }


    // MARK: Private CRUD methods

    private func setData(_ data: Data, with identifier: String, service: String, attributes: Data?) throws {
        var query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrAccount as String: identifier,
                                    kSecAttrService as String: service,
                                    kSecValueData as String: data]
        if attributes != nil {
            query[kSecAttrGeneric as String] = attributes
        }

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.storeKey(status) }

    }

    private func getData(with identifier: String, service: String) throws -> Data {
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

    private func hasData(with identifier: String, service: String) -> Bool {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrAccount as String: identifier,
                                    kSecAttrService as String: service,
                                    kSecMatchLimit as String: kSecMatchLimitOne]

        // Try to check if the seed exists.
        let status = SecItemCopyMatching(query as CFDictionary, nil)

        return status != errSecItemNotFound
    }

    private func deleteData(with identifier: String, service: String) throws {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrAccount as String: identifier,
                                    kSecAttrService as String: service]

        // Try to fetch the data if it exists.
        let status = SecItemDelete(query as CFDictionary)

        // Check the return status and throw an error if appropriate.
        guard status != errSecItemNotFound else { throw KeychainError.notFound(status) }
        guard status == errSecSuccess else { throw KeychainError.unhandledError(status) }
    }

    private func updateData(_ data: Data, with identifier: String, service: String) throws {
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
