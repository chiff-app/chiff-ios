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
    case notFound
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

    init(username: String, sites: [Site], passwordIndex: Int = 0, password: String?, context: LAContext?, completionHandler: @escaping (_ account: Account, _ error: Error?) -> Void) throws {
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

        save(password: generatedPassword, context: context, completionHandler: completionHandler)
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
//        Account.all[id] = self
    }

    mutating func deleteOtp() throws {
        try Keychain.shared.delete(id: id, service: Account.otpKeychainService)
        try backup()
    }
    
    mutating func update(username newUsername: String?, password newPassword: String?, siteName: String?, url: String?, askToLogin: Bool?, askToChange: Bool?, context: LAContext? = nil) throws {
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
            self.passwordOffset = try passwordGenerator.calculateOffset(index: passwordIndex, password: try self.password())
        }

        let accountData = try PropertyListEncoder().encode(self)
        try Keychain.shared.update(id: id, service: Account.keychainService, secretData: newPassword?.data(using: .utf8), objectData: accountData, label: nil, context: context)
        try backup()
        try Session.all().forEach({ try $0.updateAccountList(with: Account.accountList(context: context, reason: "Update account")) })
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

    func delete(context: LAContext?) throws {
        try Keychain.shared.delete(id: id, service: Account.keychainService)
        try BackupManager.shared.deleteAccount(accountId: id)
//        Account.all.removeValue(forKey: id)
        try Session.all().forEach({ try $0.updateAccountList(with: Account.accountList(context: context, reason: "Delete account")) })
        Logger.shared.analytics("Account deleted.", code: .deleteAccount, userInfo: ["siteName": site.name, "siteID": site.id])
    }

    func password(context: LAContext? = nil) throws -> String {
        do {
            let data = try Keychain.shared.get(id: id, service: Account.keychainService, context: context)

            guard let password = String(data: data, encoding: .utf8) else {
                throw CodingError.stringEncoding
            }

            return password
        } catch {
            Logger.shared.error("Could not retrieve password from account", error: error, userInfo: nil)
            throw error
        }
    }

    func password(reason: String, context: LAContext? = nil, type: AuthenticationType, completionHandler: @escaping (_ password: String?, _ error: Error?) -> Void) {
        Keychain.shared.get(id: id, service: Account.keychainService, reason: reason, with: context, authenticationType: type) { (data, error) in
            if let error = error {
                return completionHandler(nil, error)
            }
            guard let password = String(data: data!, encoding: .utf8) else {
                return completionHandler(nil, CodingError.stringEncoding)
            }
            completionHandler(password, nil)
        }
    }

    // MARK: - Static

    /*
     * This function must always be called to load the accounts
     * but is delayed because it coincides with when touchID is asked.
     */
    static func all(context: LAContext?) throws -> [String: Account] {
        guard let dataArray = try Keychain.shared.all(service: keychainService, context: context) else {
            return [:]
        }

        let decoder = PropertyListDecoder()

        return Dictionary(uniqueKeysWithValues: try dataArray.map { (dict) in
            guard let accountData = dict[kSecAttrGeneric as String] as? Data else {
                throw CodingError.unexpectedData
            }
            let account = try decoder.decode(Account.self, from: accountData)
            return (account.id, account)
        })
    }

    static func all(reason: String, type: AuthenticationType, completionHandler: @escaping (_ accounts: [String: Account]?, _ error: Error?) -> Void) {
        Keychain.shared.all(service: keychainService, reason: reason, authenticationType: type) { (dataArray, error) in
            do {
                if let error = error {
                    throw error
                }
                guard let dataArray = dataArray else {
                    throw CodingError.missingData
                }
                let decoder = PropertyListDecoder()
                let accounts: [String: Account] = Dictionary(uniqueKeysWithValues: try dataArray.map { (dict) in
                    guard let accountData = dict[kSecAttrGeneric as String] as? Data else {
                        throw CodingError.unexpectedData
                    }
                    let account = try decoder.decode(Account.self, from: accountData)
                    return (account.id, account)
                })

                completionHandler(accounts, nil)
            } catch {
                return completionHandler(nil, error)
            }
        }
    }

    static func get(accountID: String, reason: String, type: AuthenticationType, completionHandler: @escaping (_ account: Account?, _ context: LAContext?, _ error: Error?) -> Void) {
        Keychain.shared.attributes(id: accountID, service: keychainService, reason: reason, authenticationType: type) { (dict, context, error) in
            do {
                if let error = error {
                    throw error
                }
                guard let dict = dict, let context = context else {
                    throw CodingError.missingData
                }
                let decoder = PropertyListDecoder()

                guard let accountData = dict[kSecAttrGeneric as String] as? Data else {
                    return completionHandler(nil, context, CodingError.unexpectedData)
                }

                let account = try decoder.decode(Account.self, from: accountData)
                completionHandler(account, context, nil)
            } catch {
                return completionHandler(nil, nil, error)
            }
        }
    }

    static func get(accountID: String, context: LAContext?) throws -> Account? {
        guard let dict = try Keychain.shared.attributes(id: accountID, service: keychainService, context: context) else {
            return nil
        }

        let decoder = PropertyListDecoder()

        guard let accountData = dict[kSecAttrGeneric as String] as? Data else {
            throw CodingError.unexpectedData
        }

        return try decoder.decode(Account.self, from: accountData)
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

        #warning("TODO: check if this needs to be authenticated")
        try Keychain.shared.save(id: account.id, service: Account.keychainService, secretData: passwordData, objectData: data, classification: .confidential)
    }

    static func accountList(context: LAContext? = nil, reason: String? = nil, skipAuthenticationUI: Bool = false) throws -> AccountList {
        let accounts = try all(context: context)
        return accounts.mapValues({ JSONAccount(account: $0) })
    }

    static func deleteAll() {
        #warning("TODO: check if this needs to be authenticated")
        Keychain.shared.deleteAll(service: keychainService)
        Keychain.shared.deleteAll(service: otpKeychainService)
    }

    // MARK: - Private

    private func save(password: String, context: LAContext?, completionHandler: @escaping (_ account: Account, _ error: Error?) -> Void) {
        do {
            let accountData = try PropertyListEncoder().encode(self)

            guard let passwordData = password.data(using: .utf8) else {
                throw KeychainError.stringEncoding
            }

            Keychain.shared.save(id: id, service: Account.keychainService, secretData: passwordData, objectData: accountData, label: nil, reason: "Save \(site.name)", authenticationType: .ifNeeded, with: context) { (error) in
                do {
                    if let error = error {
                        throw error
                    }
                    try BackupManager.shared.backup(id: self.id, accountData: accountData)
                    try Session.all().forEach({ try $0.updateAccountList(with: Account.accountList(context: context, reason: "Save \(self.site.name)")) })
                    completionHandler(self, nil)
                } catch {
                    completionHandler(self, error)
                }
            }
        } catch {
            completionHandler(self, error)
        }
    }

}
