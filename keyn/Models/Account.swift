import Foundation

/*
 * An account belongs to the user and can have one Site.
 */
struct Account: Codable {

    let id: String
    let username: String
    let site: Site
    var passwordIndex: Int
    var passwordOffset: [Int]?
    static let keychainService = "io.keyn.account"

    init(username: String, site: Site, passwordIndex: Int = 0, password: String?) throws {
        id = try "\(site.id)_\(username)".hash()

        self.username = username
        self.site = site

        if let password = password {
            passwordOffset = try PasswordGenerator.sharedInstance.calculatePasswordOffset(username: username, passwordIndex: passwordIndex, siteID: site.id, ppd: site.ppd, password: password)
        }

        let (generatedPassword, index) = try PasswordGenerator.sharedInstance.generatePassword(username: username, passwordIndex: passwordIndex, siteID: site.id, ppd: site.ppd, offset: passwordOffset)
        self.passwordIndex = index
        if password != nil {
            assert(generatedPassword == password, "Password offset wasn't properly generated.")
        }
        
        try save(password: generatedPassword)
    }

    private func save(password: String) throws {
        let accountData = try PropertyListEncoder().encode(self)

        guard let passwordData = password.data(using: .utf8) else {
            throw KeychainError.stringEncoding
        }

        try Keychain.sharedInstance.save(secretData: passwordData, id: id, service: Account.keychainService, objectData: accountData)
    }

    func password() throws -> String {
        let data = try Keychain.sharedInstance.get(id: id, service: Account.keychainService)

        guard let password = String(data: data, encoding: .utf8) else {
            throw KeychainError.unexpectedData
        }

        return password
    }
    
    func password() throws -> Data {
        return try Keychain.sharedInstance.get(id: id, service: Account.keychainService)
    }

    mutating func updatePassword(offset: [Int]?) throws {
        let (newPassword, newIndex) = try PasswordGenerator.sharedInstance.generatePassword(username: username, passwordIndex: passwordIndex + 1, siteID: site.id, ppd: site.ppd, offset: offset)

        //TODO: Implement custom passwords here
        self.passwordIndex = newIndex

        guard let passwordData = newPassword.data(using: .utf8) else {
            throw KeychainError.stringEncoding
        }

        let accountData = try PropertyListEncoder().encode(self)

        try Keychain.sharedInstance.update(id: id, service: Account.keychainService, secretData: passwordData, objectData: accountData, label: nil)
    }

    func delete() throws {
        try Keychain.sharedInstance.delete(id: id, service: Account.keychainService)
    }

    static func get(siteID: Int) throws -> Account? {
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

    static func deleteAll() {
        Keychain.sharedInstance.deleteAll(service: keychainService)
    }

}
