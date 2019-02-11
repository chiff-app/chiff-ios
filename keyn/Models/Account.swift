/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import Foundation
import JustLog
import OneTimePassword

/*
 * An account belongs to the user and can have one Site.
 */
struct Account: Codable {
    let id: String
    var username: String
    var site: Site
    var passwordIndex: Int
    var lastPasswordUpdateTryIndex: Int
    var passwordOffset: [Int]?
    private var tokenURL: URL? // Only for backup
    private var tokenSecret: Data? // Only for backup
    static let keychainService = "io.keyn.account"
    static let otpKeychainService = "io.keyn.otp"

    init(username: String, site: Site, passwordIndex: Int = 0, password: String?) throws {
        id = "\(site.id)_\(username)".hash()

        self.username = username
        self.site = site

        if let password = password {
            passwordOffset = try PasswordGenerator.shared.calculatePasswordOffset(username: username, passwordIndex: passwordIndex, siteID: site.id, ppd: site.ppd, password: password)
        }

        let (generatedPassword, index) = try PasswordGenerator.shared.generatePassword(username: username, passwordIndex: passwordIndex, siteID: site.id, ppd: site.ppd, offset: passwordOffset)
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

        try Keychain.shared.save(secretData: passwordData, id: id, service: Account.keychainService, objectData: accountData, classification: .confidential)
        try BackupManager.shared.backup(id: id, accountData: accountData)
    }
    
    mutating func backup() throws {
        if let token = try oneTimePasswordToken() {
            tokenSecret = token.generator.secret
            tokenURL = try token.toURL()
        }

        let accountData = try PropertyListEncoder().encode(self)
        try BackupManager.shared.backup(id: id, accountData: accountData)
    }

    func password() throws -> String {
        let data = try Keychain.shared.get(id: id, service: Account.keychainService)

        guard let password = String(data: data, encoding: .utf8) else {
            throw KeychainError.unexpectedData
        }

        return password
    }
    
    mutating func nextPassword(offset: [Int]?) throws -> String {
        let (newPassword, index) = try PasswordGenerator.shared.generatePassword(username: username, passwordIndex: lastPasswordUpdateTryIndex + 1, siteID: site.id, ppd: site.ppd, offset: offset)
        self.lastPasswordUpdateTryIndex = index
        let accountData = try PropertyListEncoder().encode(self)
        try Keychain.shared.update(id: id, service: Account.keychainService, secretData: nil, objectData: accountData, label: nil)
        return newPassword
    }
    
    // OTP
    
    func oneTimePasswordToken() throws -> Token? {
        guard let urlDataDict = try Keychain.shared.attributes(id: id, service: Account.otpKeychainService) else {
            return nil
        }
        let secret = try Keychain.shared.get(id: id, service: Account.otpKeychainService)
        guard let urlData = urlDataDict[kSecAttrGeneric as String] as? Data, let urlString = String(data: urlData, encoding: .utf8),
            let url = URL(string: urlString) else {
                throw KeychainError.unexpectedData
        }
        
        return Token(url: url, secret: secret)
    }
    
    func hasOtp() -> Bool {
        return Keychain.shared.has(id: id, service: Account.otpKeychainService)
    }
    
    mutating func addOtp(token: Token) throws {
        let secret = token.generator.secret
        guard let tokenData = try token.toURL().absoluteString.data(using: .utf8) else {
            throw KeychainError.stringEncoding
        }
        try Keychain.shared.save(secretData: secret, id: id, service: Account.otpKeychainService, objectData: tokenData, classification: .secret)
        try backup()
    }
    
    mutating func updateOtp(token: Token) throws {
        let secret = token.generator.secret
        guard let tokenData = try token.toURL().absoluteString.data(using: .utf8) else {
            throw KeychainError.stringEncoding
        }
        try Keychain.shared.update(id: id, service: Account.otpKeychainService, secretData: secret, objectData: tokenData, label: nil)
        try backup()
    }
    
    mutating func deleteOtp() throws {
        try Keychain.shared.delete(id: id, service: Account.otpKeychainService)
        try backup()
    }
    
    mutating func update(username newUsername: String?, password newPassword: String?, siteName: String?, url: String?) throws {
        if let newUsername = newUsername {
            self.username = newUsername
        }
        if let siteName = siteName {
            self.site.name = siteName
        }
        if let url = url {
            self.site.url = url
        }
        
        if let newPassword = newPassword {
            let newIndex = passwordIndex + 1
            self.passwordOffset = try PasswordGenerator.shared.calculatePasswordOffset(username: self.username, passwordIndex: newIndex, siteID: site.id, ppd: site.ppd, password: newPassword)
            self.passwordIndex = newIndex
            self.lastPasswordUpdateTryIndex = newIndex
        } else if let newUsername = newUsername {
           self.passwordOffset = try PasswordGenerator.shared.calculatePasswordOffset(username: newUsername, passwordIndex: passwordIndex, siteID: site.id, ppd: site.ppd, password: try self.password())
        }
        
        let accountData = try PropertyListEncoder().encode(self)
        try Keychain.shared.update(id: id, service: Account.keychainService, secretData: newPassword?.data(using: .utf8), objectData: accountData, label: nil)
        try backup()
    }

    mutating func updatePassword(offset: [Int]?) throws {
        let (newPassword, newIndex) = try PasswordGenerator.shared.generatePassword(username: username, passwordIndex: lastPasswordUpdateTryIndex, siteID: site.id, ppd: site.ppd, offset: offset)

        self.passwordIndex = newIndex
        self.lastPasswordUpdateTryIndex = newIndex
        passwordOffset = offset

        guard let passwordData = newPassword.data(using: .utf8) else {
            throw KeychainError.stringEncoding
        }

        let accountData = try PropertyListEncoder().encode(self)

        try Keychain.shared.update(id: id, service: Account.keychainService, secretData: passwordData, objectData: accountData, label: nil)
        try backup()
        Logger.shared.info("Password changed.", userInfo: ["code": AnalyticsMessage.passwordChange.rawValue, "siteName": site.name, "siteID": site.id])
    }

    func delete() throws {
        try Keychain.shared.delete(id: id, service: Account.keychainService)
        try BackupManager.shared.deleteAccount(accountId: id)
        Logger.shared.info("Account deleted.", userInfo: ["code": AnalyticsMessage.deleteAccount.rawValue, "siteName": site.name, "siteID": site.id])
    }

    static func get(siteID: String) throws -> [Account] {
        // TODO: optimize when we're bored
        let accounts = try Account.all()

        return accounts.filter { (account) -> Bool in
            account.site.id == siteID
        }
    }
    
    static func get(accountID: String) throws -> Account? {
        let accounts = try Account.all()
        guard !accounts.isEmpty else {
            return nil
        }
        
        return accounts.first { (account) -> Bool in
            account.id == accountID
        }
    }
    
    static func save(accountData: Data, id: String) throws {
        let decoder = PropertyListDecoder()
        var account = try decoder.decode(Account.self, from: accountData)
        let data: Data
        
        assert(account.id == id, "Account restoring went wrong. Different id")

        let (password, index) = try PasswordGenerator.shared.generatePassword(username: account.username, passwordIndex: account.passwordIndex, siteID: account.site.id, ppd: account.site.ppd, offset: account.passwordOffset)
        
        assert(index == account.passwordIndex, "Password wasn't properly generated. Different index")
        
        guard let passwordData = password.data(using: .utf8) else {
            throw KeychainError.stringEncoding
        }
    
        // Remove token and save seperately in Keychain
        if let tokenSecret = account.tokenSecret, let tokenURL = account.tokenURL {
            account.tokenSecret = nil
            account.tokenURL = nil
            guard let tokenData = tokenURL.absoluteString.data(using: .utf8) else {
                throw KeychainError.stringEncoding
            }
            try Keychain.shared.save(secretData: tokenSecret, id: id, service: Account.otpKeychainService, objectData: tokenData, classification: .secret)
            data = try PropertyListEncoder().encode(account)
        } else {
            data = accountData
        }

        try Keychain.shared.save(secretData: passwordData, id: account.id, service: Account.keychainService, objectData: data, classification: .confidential)
    }

    static func all() throws -> [Account] {
        guard let dataArray = try Keychain.shared.all(service: keychainService) else {
            return []
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
        Keychain.shared.deleteAll(service: keychainService)
        Keychain.shared.deleteAll(service: otpKeychainService)
    }
}
