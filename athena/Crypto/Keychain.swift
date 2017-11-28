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
    
    private static let sharedInstance = Keychain()
    
    static let passwords = Passwords(keychain: sharedInstance)
    static let sessions = Sessions(keychain: sharedInstance)
    static let seed = Seed(keychain: sharedInstance)
    
    private init() {} //This prevents others from using the default '()' initializer for this singleton class.

    // TODO: Add accessability restrictions

    // MARK: Password operations
    
    class Passwords {
        
        private let keychain: Keychain
        let service = "com.athena.password"
        
        fileprivate init(keychain: Keychain) {
            self.keychain = keychain
        }
        
        func save(_ password: String, account: Data, with identifier: String) throws {
            guard let passwordData = password.data(using: .utf8) else {
                throw KeychainError.stringEncoding
            }
            try keychain.setData(passwordData, with: identifier, service: service, attributes: account)
        }
        
        func get(with identifier: String) throws -> String {
            let data = try keychain.getData(with: identifier, service: service)
            
            guard let password = String(data: data, encoding: .utf8) else {
                throw KeychainError.unexpectedData
            }
            
            return password
        }
        
        func update(_ newPassword: String, with identifier: String) throws {
            guard let passwordData = newPassword.data(using: .utf8) else {
                throw KeychainError.stringEncoding
            }
            try keychain.updateData(passwordData, with: identifier, service: service)
        }
        
        func delete(with identifier: String) throws {
            try keychain.deleteData(with: identifier, service: service)
        }
        
        func getAll() throws -> [Account]? {
            guard let dataArray = try keychain.getAll(service: service) else {
                return nil
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
        
    }


    // MARK: Seed operations
    
    class Seed {
        
        private let keychain: Keychain
        let service = "com.athena.seed"
        
        fileprivate init(keychain: Keychain) {
            self.keychain = keychain
        }
        
        func save(seed: Data) throws {
            try keychain.setData(seed, with: service, service: service, attributes: nil)
        }
        
        func get() throws -> Data {
            return try keychain.getData(with: service, service: service)
        }
        
        func has() -> Bool {
            return keychain.hasData(with: service, service: service)
        }
        
        func delete() throws {
            try keychain.deleteData(with: service, service: service)
        }
    }

    
    // MARK: Session key operations
    
    class Sessions {
        
        private let keychain: Keychain
        let browserService = "com.athena.session.browser"
        let appService = "com.athena.session"
        
        fileprivate init(keychain: Keychain) {
            self.keychain = keychain
        }
    
        
        func saveBrowserKey(_ keyData: Data, with identifier: String, attributes: Data) throws {
            try keychain.setData(keyData, with: identifier, service: browserService, attributes: attributes)
        }
        
        func getBrowserKey(with identifier: String) throws -> Data {
            return try keychain.getData(with: identifier, service: browserService)
        }
        
        func deleteBrowserKey(with identifier: String) throws {
            try keychain.deleteData(with: identifier, service: browserService)
        }
        
        func saveAppKey(_ keyData: Data, with identifier: String) throws {
            try keychain.setData(keyData, with: identifier, service: appService, attributes: nil)
        }
        
        
        func getAppKey(with identifier: String) throws -> Data {
            return try keychain.getData(with: identifier, service: appService)
        }
        
        
        func deleteAppKey(with identifier: String) throws {
            try keychain.deleteData(with: identifier, service: appService)
        }
        
        func getAll() throws -> [Session]? {
            guard let dataArray = try keychain.getAll(service: browserService) else {
                return nil
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
        
    }


    // MARK: fileprivate CRUD methods

    fileprivate func setData(_ data: Data, with identifier: String, service: String, attributes: Data?) throws {
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

    fileprivate func getData(with identifier: String, service: String) throws -> Data {
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

    fileprivate func hasData(with identifier: String, service: String) -> Bool {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrAccount as String: identifier,
                                    kSecAttrService as String: service,
                                    kSecMatchLimit as String: kSecMatchLimitOne]

        // Try to check if the seed exists.
        let status = SecItemCopyMatching(query as CFDictionary, nil)

        return status != errSecItemNotFound
    }

    fileprivate func deleteData(with identifier: String, service: String) throws {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrAccount as String: identifier,
                                    kSecAttrService as String: service]

        // Try to fetch the data if it exists.
        let status = SecItemDelete(query as CFDictionary)

        // Check the return status and throw an error if appropriate.
        guard status != errSecItemNotFound else { throw KeychainError.notFound(status) }
        guard status == errSecSuccess else { throw KeychainError.unhandledError(status) }
    }

    fileprivate func updateData(_ data: Data, with identifier: String, service: String) throws {
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
    
    fileprivate func getAll(service: String) throws -> [[String: Any]]? {
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

}
