import Foundation
import JustLog

/*
 * An account belongs to the user and can have one Site.
 */
struct Account: Codable {

    let id: String
    let username: String
    let site: Site
    var passwordIndex: Int
    var lastPasswordUpdateTryIndex: Int
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
        self.lastPasswordUpdateTryIndex = index
        if password != nil {
            assert(generatedPassword == password, "Password offset wasn't properly generated.")
        }
        
        Logger.shared.info("Site added to Keyn.", userInfo: ["code": AnalyticsMessage.siteAdded.rawValue, "changed": password == nil, "siteID": site.id, "siteName": site.name])
        
        try save(password: generatedPassword)
    }

    private func save(password: String) throws {
        let accountData = try PropertyListEncoder().encode(self)

        guard let passwordData = password.data(using: .utf8) else {
            throw KeychainError.stringEncoding
        }

        try Keychain.sharedInstance.save(secretData: passwordData, id: id, service: Account.keychainService, objectData: accountData)
        try BackupManager.sharedInstance.backup(id: id, accountData: accountData)
    }
    
    func backup() throws {
        let accountData = try PropertyListEncoder().encode(self)
        try BackupManager.sharedInstance.backup(id: id, accountData: accountData)
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

    mutating func nextPassword(offset: [Int]?) throws -> String {
        let (newPassword, index) = try PasswordGenerator.sharedInstance.generatePassword(username: username, passwordIndex: lastPasswordUpdateTryIndex + 1, siteID: site.id, ppd: site.ppd, offset: offset)
        self.lastPasswordUpdateTryIndex = index
        let accountData = try PropertyListEncoder().encode(self)
        try Keychain.sharedInstance.update(id: id, service: Account.keychainService, secretData: nil, objectData: accountData, label: nil)
        return newPassword
    }

    mutating func updatePassword(offset: [Int]?) throws {
        let (newPassword, newIndex) = try PasswordGenerator.sharedInstance.generatePassword(username: username, passwordIndex: lastPasswordUpdateTryIndex, siteID: site.id, ppd: site.ppd, offset: offset)

        //TODO: Implement custom passwords here
        self.passwordIndex = newIndex
        self.lastPasswordUpdateTryIndex = newIndex
        passwordOffset = offset

        guard let passwordData = newPassword.data(using: .utf8) else {
            throw KeychainError.stringEncoding
        }

        let accountData = try PropertyListEncoder().encode(self)

        try Keychain.sharedInstance.update(id: id, service: Account.keychainService, secretData: passwordData, objectData: accountData, label: nil)
        try BackupManager.sharedInstance.backup(id: id, accountData: accountData)
        Logger.shared.info("Password changed.", userInfo: ["code": AnalyticsMessage.passwordChange.rawValue, "siteName": site.name, "siteID": site.id])
    }

    func delete() throws {
        try Keychain.sharedInstance.delete(id: id, service: Account.keychainService)
        try BackupManager.sharedInstance.deleteAccount(accountId: id)
        Logger.shared.info("Account deleted.", userInfo: ["code": AnalyticsMessage.deleteAccount.rawValue, "siteName": site.name, "siteID": site.id])
    }

    static func get(siteID: String) throws -> [Account] {
        // TODO: optimize when we're bored
        guard let accounts = try Account.all() else {
            return [Account]()
        }

        return accounts.filter { (account) -> Bool in
            account.site.id == siteID
        }
    }
    
    static func get(accountID: String) throws -> Account? {
        guard let accounts = try Account.all() else {
            return nil
        }
        
        return accounts.first { (account) -> Bool in
            account.id == accountID
        }
    }
    
    static func save(accountData: Data, id: String) throws {
        let decoder = PropertyListDecoder()
        let account = try decoder.decode(Account.self, from: accountData)
        
        assert(account.id == id, "Account restoring went wrong. Different id")

        let (password, index) = try PasswordGenerator.sharedInstance.generatePassword(username: account.username, passwordIndex: account.passwordIndex, siteID: account.site.id, ppd: account.site.ppd, offset: account.passwordOffset)
        
        assert(index == account.passwordIndex, "Password wasn't properly generated. Different index")
        
        guard let passwordData = password.data(using: .utf8) else {
            throw KeychainError.stringEncoding
        }
        
        try Keychain.sharedInstance.save(secretData: passwordData, id: account.id, service: Account.keychainService, objectData: accountData)
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
            let account = try decoder.decode(Account.self, from: accountData)
            accounts.append(account)
        }
        return accounts
    }

    static func deleteAll() {
        Keychain.sharedInstance.deleteAll(service: keychainService)
    }

}
