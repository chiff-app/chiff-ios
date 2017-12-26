import Foundation

/*
 * An account belongs to the user and can have one or more Sites.
 */
struct Account: Codable {

    let id: String
    let username: String
    let site: Site
    var passwordIndex: Int
    let restrictions: PasswordRestrictions
    var offset: [Int]?
    static let keychainService = "com.athena.account"

    init(username: String, site: Site, passwordIndex: Int = 0, password: String?) throws {
        id = try "\(site.id)_\(username)".hash()

        self.username = username
        self.site = site
        self.passwordIndex = passwordIndex
        self.restrictions = site.restrictions // Use site default restrictions of no custom restrictions are provided
        if let password = password {
            offset = try Crypto.sharedInstance.calculatePasswordOffset(username: username, passwordIndex: passwordIndex, siteID: site.id, restrictions: restrictions, password: password)
        }
        
        try save(password: password)
    }

    private func save(password: String?) throws {
        let accountData = try PropertyListEncoder().encode(self)
        
        let generatedPassword = try Crypto.sharedInstance.generatePassword(username: username, passwordIndex: passwordIndex, siteID: site.id, restrictions: restrictions, offset: offset)
        
        if password != nil {
            assert(generatedPassword == password, "Password offset wasn't properly generated.")
        }

        guard let passwordData = generatedPassword.data(using: .utf8) else {
            throw KeychainError.stringEncoding
        }

        try Keychain.sharedInstance.save(passwordData, id: id, service: Account.keychainService, attributes: accountData)
    }

    func password() throws -> String {
        let data = try Keychain.sharedInstance.get(id: id, service: Account.keychainService)

        guard let password = String(data: data, encoding: .utf8) else {
            throw KeychainError.unexpectedData
        }

        return password
    }

    mutating func updatePassword(restrictions: PasswordRestrictions) throws {
        passwordIndex += 1

        let newPassword = try Crypto.sharedInstance.generatePassword(username: username, passwordIndex: passwordIndex, siteID: site.id, restrictions: restrictions, offset: offset)
        //TODO: Implement custom passwords here

        guard let passwordData = newPassword.data(using: .utf8) else {
            throw KeychainError.stringEncoding
        }

        try Keychain.sharedInstance.update(passwordData, id: id, service: Account.keychainService)
    }

    func delete() throws {
        try Keychain.sharedInstance.delete(id: id, service: Account.keychainService)
    }

    static func get(siteID: String) throws -> Account? {
        // TODO: optimize when we're bored
        guard let accounts = try Account.all() else {
            return nil
        }
        for account in accounts {
            if account.site.id == siteID {
                return account
            }
        }
        return nil
    }

    static func all() throws -> [Account]? {
        guard let dataArray = try Keychain.sharedInstance.all(service: keychainService) else {
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


