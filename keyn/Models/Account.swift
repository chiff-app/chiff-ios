/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import Foundation
import OneTimePassword
import LocalAuthentication
import AuthenticationServices

enum AccountError: KeynError {
    case duplicateAccountId
    case accountsNotLoaded
}

/*
 * An account belongs to the user and can have one Site.
 */
struct Account: Codable {

    let id: String
    var username: String
    var sites: [Site]
    var site: Site {
        return sites[0]
    }
    var passwordIndex: Int
    var lastPasswordUpdateTryIndex: Int
    var passwordOffset: [Int]?
    var askToLogin: Bool = true
    var askToChange: Bool = true
    private var tokenURL: URL? // Only for backup
    private var tokenSecret: Data? // Only for backup

    static let keychainService = "io.keyn.account"
    static let otpKeychainService = "io.keyn.otp"
    static var all: [String: Account]!

    init(username: String, sites: [Site], passwordIndex: Int = 0, password: String?) throws {
        guard Account.all != nil else {
            throw AccountError.accountsNotLoaded
        }
        id = "\(sites[0].id)_\(username)".hash

        self.sites = sites
        self.username = username

        let passwordGenerator = PasswordGenerator(username: username, siteId: sites[0].id, ppd: sites[0].ppd)
        if let password = password {
            passwordOffset = try passwordGenerator.calculateOffset(index: passwordIndex, password: password)
        }

        let (generatedPassword, index) = try passwordGenerator.generate(index: passwordIndex, offset: passwordOffset)
        self.passwordIndex = index
        self.lastPasswordUpdateTryIndex = index
        if password != nil {
            assert(generatedPassword == password, "Password offset wasn't properly generated.")
        }

        try save(password: generatedPassword)
        Account.all[id] = self
        try Session.all().forEach({ try $0.updateAccountList() })
        
        Logger.shared.analytics("Site added to Keyn.", code: .siteAdded, userInfo: ["changed": password == nil, "siteID": site.id, "siteName": site.name])
    }

    /*
     * This function must always be called to load the accounts
     * but is delayed because it coincides with when touchID is asked.
     */
    static func loadAll(context: LAContext?, reason: String, skipAuthenticationUI: Bool = false) throws -> [String: Account] {
        guard all == nil else {
            return all
        }
        #warning("Check what this returns if there are no accounts")
        guard let dataArray = try Keychain.shared.all(service: keychainService, reason: reason, context: context, skipAuthenticationUI: skipAuthenticationUI) else {
            all = [:]
            return all
        }

        let decoder = PropertyListDecoder()

        for dict in dataArray {
            guard let accountData = dict[kSecAttrGeneric as String] as? Data else {
                throw CodingError.unexpectedData
            }
            let account = try decoder.decode(Account.self, from: accountData)
            guard !all.keys.contains(account.id) else {
                throw AccountError.duplicateAccountId
            }
            all[account.id] = account
        }

        if #available(iOS 12.0, *) {
            let identities = all.values.map { (account) -> ASPasswordCredentialIdentity in
                let identifier = ASCredentialServiceIdentifier(identifier: account.site.url, type: ASCredentialServiceIdentifier.IdentifierType.URL)
                return ASPasswordCredentialIdentity(serviceIdentifier: identifier, user: account.username, recordIdentifier: account.id)
            }
            ASCredentialIdentityStore.shared.saveCredentialIdentities(identities, completion: nil)
        }

        return all
    }

    mutating func backup() throws {
        if let token = try oneTimePasswordToken() {
            tokenSecret = token.generator.secret
            tokenURL = try token.toURL()
        }

        let accountData = try PropertyListEncoder().encode(self)
        try BackupManager.shared.backup(id: id, accountData: accountData)
    }

    mutating func nextPassword() throws -> String {
        let offset: [Int]? = nil // Will it be possible to change to custom password?
        let passwordGenerator = PasswordGenerator(username: username, siteId: site.id, ppd: site.ppd)
        let (newPassword, index) = try passwordGenerator.generate(index: lastPasswordUpdateTryIndex + 1, offset: offset)
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
                throw CodingError.unexpectedData
        }
        
        return Token(url: url, secret: secret)
    }
    
    func hasOtp() -> Bool {
        return Keychain.shared.has(id: id, service: Account.otpKeychainService)
    }

    mutating func setOtp(token: Token) throws {
        let secret = token.generator.secret

        guard let tokenData = try token.toURL().absoluteString.data(using: .utf8) else {
            throw CodingError.stringEncoding
        }

        if self.hasOtp() {
            try Keychain.shared.update(id: id, service: Account.otpKeychainService, secretData: secret, objectData: tokenData, label: nil)
        } else {
            try Keychain.shared.save(id: id, service: Account.otpKeychainService, secretData: secret, objectData: tokenData, classification: .secret)
        }
        try backup()
        Account.all[id] = self
    }

    mutating func deleteOtp() throws {
        try Keychain.shared.delete(id: id, service: Account.otpKeychainService)
        try backup()
    }
    
    mutating func update(username newUsername: String?, password newPassword: String?, siteName: String?, url: String?, askToLogin: Bool?, askToChange: Bool?) throws {
        if let newUsername = newUsername {
            self.username = newUsername
        }
        #warning("TODO: Update accounts with multiple sites")
        if let siteName = siteName {
            self.sites[0].name = siteName
        }
        if let url = url {
            self.sites[0].url = url
        }
        if let askToLogin = askToLogin {
            self.askToLogin = askToLogin
        }
        if let askToChange = askToChange {
            self.askToChange = askToChange
        }

        if let newPassword = newPassword {
            let newIndex = passwordIndex + 1
            let passwordGenerator = PasswordGenerator(username: self.username, siteId: site.id, ppd: site.ppd)
            self.passwordOffset = try passwordGenerator.calculateOffset(index: newIndex, password: newPassword)
            self.passwordIndex = newIndex
            self.lastPasswordUpdateTryIndex = newIndex
        } else if let newUsername = newUsername {
            let passwordGenerator = PasswordGenerator(username: newUsername, siteId: site.id, ppd: site.ppd)
            self.passwordOffset = try passwordGenerator.calculateOffset(index: passwordIndex, password: try self.password(reason: "Update password"))
        }

        let accountData = try PropertyListEncoder().encode(self)
        try Keychain.shared.update(id: id, service: Account.keychainService, secretData: newPassword?.data(using: .utf8), objectData: accountData, label: nil)
        Account.all[id] = self
        try backup()
        try Session.all().forEach({ try $0.updateAccountList() })
    }

    /*
     * After saving a new (generated) password in the browser we place a message
     * on the queue stating that it succeeded. We can then call this function to
     * confirm the new password and store it in the account.
     */
    mutating func updatePasswordAfterConfirmation() throws {
        let offset: [Int]? = nil // Will it be possible to change to custom password?

        let passwordGenerator = PasswordGenerator(username: username, siteId: site.id, ppd: site.ppd)
        let (newPassword, newIndex) = try passwordGenerator.generate(index: lastPasswordUpdateTryIndex, offset: offset)

        self.passwordIndex = newIndex
        self.lastPasswordUpdateTryIndex = newIndex
        passwordOffset = offset

        guard let passwordData = newPassword.data(using: .utf8) else {
            throw CodingError.stringEncoding
        }

        let accountData = try PropertyListEncoder().encode(self)

        try Keychain.shared.update(id: id, service: Account.keychainService, secretData: passwordData, objectData: accountData, label: nil)
        try backup()
        Logger.shared.analytics("Password changed.", code: .passwordChange, userInfo: ["siteName": site.name, "siteID": site.id])
    }

    func delete() throws {
        try Keychain.shared.delete(id: id, service: Account.keychainService)
        try BackupManager.shared.deleteAccount(accountId: id)
        Account.all.removeValue(forKey: id)
        try Session.all().forEach({ try $0.updateAccountList() })
        Logger.shared.analytics("Account deleted.", code: .deleteAccount, userInfo: ["siteName": site.name, "siteID": site.id])
    }

    func password(reason: String, context: LAContext? = nil, skipAuthenticationUI: Bool = false) throws -> String {
        do {
            let data = try Keychain.shared.get(id: id, service: Account.keychainService, reason: reason, context: context, skipAuthenticationUI: skipAuthenticationUI)

            guard let password = String(data: data, encoding: .utf8) else {
                throw CodingError.stringEncoding
            }

            return password
        } catch {
            Logger.shared.error("Could not retrieve password from account", error: error, userInfo: nil)
            throw error
        }
    }

    // MARK: - Static

    #warning("TODO: Can be optimized")
    static func get(siteID: String) throws -> [Account] {
        guard Account.all != nil else {
            throw AccountError.accountsNotLoaded
        }
        return Account.all.values.filter { $0.site.id == siteID }
    }
    
    static func get(accountID: String) throws -> Account? {
        guard Account.all != nil else {
            throw AccountError.accountsNotLoaded
        }
        return Account.all[accountID]
    }
    
    static func save(accountData: Data, id: String) throws {
        let decoder = PropertyListDecoder()
        var account = try decoder.decode(Account.self, from: accountData)
        let data: Data
        
        assert(account.id == id, "Account restoring went wrong. Different id")

        let passwordGenerator = PasswordGenerator(username: account.username, siteId: account.site.id, ppd: account.site.ppd)
        let (password, index) = try passwordGenerator.generate(index: account.passwordIndex, offset: account.passwordOffset)
        
        assert(index == account.passwordIndex, "Password wasn't properly generated. Different index")
        
        guard let passwordData = password.data(using: .utf8) else {
            throw CodingError.stringEncoding
        }
    
        // Remove token and save seperately in Keychain
        if let tokenSecret = account.tokenSecret, let tokenURL = account.tokenURL {
            account.tokenSecret = nil
            account.tokenURL = nil
            guard let tokenData = tokenURL.absoluteString.data(using: .utf8) else {
                throw CodingError.stringEncoding
            }
            try Keychain.shared.save(id: id, service: Account.otpKeychainService, secretData: tokenSecret, objectData: tokenData, classification: .secret)
            data = try PropertyListEncoder().encode(account)
        } else {
            data = accountData
        }

        try Keychain.shared.save(id: account.id, service: Account.keychainService, secretData: passwordData, objectData: data, classification: .confidential, reason: "Save \(account.site.name)")
    }

    static func accountList() -> AccountList {
        return all.mapValues({ JSONAccount(account: $0) })
    }

    static func deleteAll() {
        Keychain.shared.deleteAll(service: keychainService)
        Keychain.shared.deleteAll(service: otpKeychainService)
    }

    // MARK: - Private

    private func save(password: String) throws {
        let accountData = try PropertyListEncoder().encode(self)

        guard let passwordData = password.data(using: .utf8) else {
            throw KeychainError.stringEncoding
        }

        try Keychain.shared.save(id: id, service: Account.keychainService, secretData: passwordData, objectData: accountData, classification: .confidential, reason: "Save \(site.name)")
        try BackupManager.shared.backup(id: id, accountData: accountData)
    }

}
