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
    case missingContext
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
    var askToLogin: Bool?
    var askToChange: Bool?
    fileprivate var tokenURL: URL? // Only for backup
    fileprivate var tokenSecret: Data? // Only for backup

    init(username: String, sites: [Site], passwordIndex: Int = 0, password: String?, context: LAContext? = nil) throws {
        id = "\(sites[0].id)_\(username)".hash

        self.sites = sites
        self.username = username

        let passwordGenerator = PasswordGenerator(username: username, siteId: sites[0].id, ppd: sites[0].ppd)
        if let password = password {
            passwordOffset = try passwordGenerator.calculateOffset(index: passwordIndex, password: password)
        } else {
            askToChange = false
        }
        
        let (generatedPassword, index) = try passwordGenerator.generate(index: passwordIndex, offset: passwordOffset)
        self.passwordIndex = index  
        self.lastPasswordUpdateTryIndex = index
        if password != nil {
            assert(generatedPassword == password, "Password offset wasn't properly generated.")
        }

        try save(password: generatedPassword, context: context)
    }

    mutating func backup() throws {
        if let token = try oneTimePasswordToken() {
            tokenSecret = token.generator.secret
            tokenURL = try token.toURL()
        }

        let accountData = try JSONEncoder().encode(self)
        try BackupManager.shared.backup(id: id, accountData: accountData)
    }

    mutating func nextPassword(context: LAContext? = nil) throws -> String {
        let offset: [Int]? = nil // Will it be possible to change to custom password?
        let passwordGenerator = PasswordGenerator(username: username, siteId: site.id, ppd: site.ppd)
        let (newPassword, index) = try passwordGenerator.generate(index: lastPasswordUpdateTryIndex + 1, offset: offset)
        self.lastPasswordUpdateTryIndex = index
        let accountData = try PropertyListEncoder().encode(self)
        try Keychain.shared.update(id: id, service: .account, secretData: nil, objectData: accountData, label: nil, context: context)
        return newPassword
    }
    
    // OTP
    
    func oneTimePasswordToken() throws -> Token? {
        guard let urlDataDict = try Keychain.shared.attributes(id: id, service: .otp, context: nil) else {
            return nil
        }
        let secret = try Keychain.shared.get(id: id, service: .otp, context: nil)
        guard let urlData = urlDataDict[kSecAttrGeneric as String] as? Data, let urlString = String(data: urlData, encoding: .utf8),
            let url = URL(string: urlString) else {
                throw CodingError.unexpectedData
        }
        
        return Token(url: url, secret: secret)
    }
    
    func hasOtp() -> Bool {
        return Keychain.shared.has(id: id, service: .otp)
    }

    mutating func setOtp(token: Token) throws {
        let secret = token.generator.secret
        let tokenData = try token.toURL().absoluteString.data

        if self.hasOtp() {
            try Keychain.shared.update(id: id, service: .otp, secretData: secret, objectData: tokenData, label: nil)
        } else {
            try Keychain.shared.save(id: id, service: .otp, secretData: secret, objectData: tokenData)
        }
        try backup()
    }

    mutating func deleteOtp() throws {
        try Keychain.shared.delete(id: id, service: .otp)
        try backup()
    }

    mutating func addSite(site: Site) throws {
        self.sites.append(site)
        let accountData = try PropertyListEncoder().encode(self)
        try Keychain.shared.update(id: id, service: .account, secretData: nil, objectData: accountData, label: nil, context: nil)
        try backup()
        try Session.all().forEach({ try $0.updateAccountList(with: Account.accountList(context: nil)) })
        Account.saveToIdentityStore(account: self)
    }

    mutating func removeSite(forIndex index: Int) throws {
        self.sites.remove(at: index)
        let accountData = try PropertyListEncoder().encode(self)
        try Keychain.shared.update(id: id, service: .account, secretData: nil, objectData: accountData, label: nil, context: nil)
        try backup()
        try Session.all().forEach({ try $0.updateAccountList(with: Account.accountList(context: nil)) })
        Account.saveToIdentityStore(account: self)
    }

    mutating func updateSite(url: String, forIndex index: Int) throws {
        self.sites[index].url = url
        let accountData = try PropertyListEncoder().encode(self)
        try Keychain.shared.update(id: id, service: .account, secretData: nil, objectData: accountData, label: nil, context: nil)
        try backup()
        try Session.all().forEach({ try $0.updateAccountList(with: Account.accountList(context: nil)) })
        Account.saveToIdentityStore(account: self)
    }
    
    mutating func update(username newUsername: String?, password newPassword: String?, siteName: String?, url: String?, askToLogin: Bool?, askToChange: Bool?, context: LAContext? = nil) throws {
        if let newUsername = newUsername {
            self.username = newUsername
        }
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
            if askToChange == nil {
                self.askToChange = true
            }
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
        try Keychain.shared.update(id: id, service: .account, secretData: newPassword?.data, objectData: accountData, label: nil, context: context)
        try backup()
        try Session.all().forEach({ try $0.updateAccountList(with: Account.accountList(context: context)) })
        Account.saveToIdentityStore(account: self)
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
        askToChange = false

        let accountData = try PropertyListEncoder().encode(self)

        try Keychain.shared.update(id: id, service: .account, secretData: newPassword.data, objectData: accountData, label: nil)
        try backup()
        try Session.all().forEach({ try $0.updateAccountList(with: Account.accountList(context: nil)) })
        Logger.shared.analytics("Password changed.", code: .passwordChange, userInfo: ["siteName": site.name, "siteID": site.id])
    }

    func delete(completionHandler: @escaping (_ error: Error?) -> Void) {
        Keychain.shared.delete(id: id, service: .account, reason: "Delete \(site.name)", authenticationType: .ifNeeded) { (context, error) in
            do {
                if let error = error {
                    throw error
                }
                try BackupManager.shared.deleteAccount(accountId: self.id)
                try Session.all().forEach({ try $0.updateAccountList(with: Account.accountList(context: context)) })
                Account.deleteFromToIdentityStore(account: self)
                Logger.shared.analytics("Account deleted.", code: .deleteAccount, userInfo: ["siteName": self.site.name, "siteID": self.site.id])
                completionHandler(nil)
            } catch {
                Logger.shared.error("Error deleting accounts", error: error)
                return completionHandler(error)
            }
        }
    }

    func password(context: LAContext? = nil) throws -> String {
        do {
            let data = try Keychain.shared.get(id: id, service: .account, context: context)

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
        Keychain.shared.get(id: id, service: .account, reason: reason, with: context, authenticationType: type) { (data, error) in
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
        guard let dataArray = try Keychain.shared.all(service: .account, context: context) else {
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

    static func get(accountID: String, context: LAContext?) throws -> Account? {
        guard let dict = try Keychain.shared.attributes(id: accountID, service: .account, context: context) else {
            return nil
        }

        let decoder = PropertyListDecoder()

        guard let accountData = dict[kSecAttrGeneric as String] as? Data else {
            throw CodingError.unexpectedData
        }

        return try decoder.decode(Account.self, from: accountData)
    }
    
    static func save(accountData: Data, id: String) throws {
        let decoder = JSONDecoder()
        var account = try decoder.decode(Account.self, from: accountData)

        assert(account.id == id, "Account restoring went wrong. Different id")

        let passwordGenerator = PasswordGenerator(username: account.username, siteId: account.site.id, ppd: account.site.ppd)
        let (password, index) = try passwordGenerator.generate(index: account.passwordIndex, offset: account.passwordOffset)
        
        assert(index == account.passwordIndex, "Password wasn't properly generated. Different index")

        // Remove token and save seperately in Keychain
        if let tokenSecret = account.tokenSecret, let tokenURL = account.tokenURL {
            account.tokenSecret = nil
            account.tokenURL = nil
            let tokenData = tokenURL.absoluteString.data
            try Keychain.shared.save(id: id, service: .otp, secretData: tokenSecret, objectData: tokenData)
        }

        let data = try PropertyListEncoder().encode(account)

        try Keychain.shared.save(id: account.id, service: .account, secretData: password.data, objectData: data)
        saveToIdentityStore(account: account)
    }

    static func accountList(context: LAContext? = nil) throws -> AccountList {
        return try all(context: context).mapValues({ JSONAccount(account: $0) })
    }

    static func deleteAll() {
        Keychain.shared.deleteAll(service: .account)
        Keychain.shared.deleteAll(service: .otp)
        if #available(iOS 12.0, *) {
            ASCredentialIdentityStore.shared.removeAllCredentialIdentities(nil)
        }
    }

    // MARK: - Private

    private func save(password: String, context: LAContext?) throws {
        let accountData = try PropertyListEncoder().encode(self)
        try Keychain.shared.save(id: id, service: .account, secretData: password.data, objectData: accountData, label: nil)
        try BackupManager.shared.backup(id: self.id, accountData: accountData)
        try Session.all().forEach({ try $0.updateAccountList(with: Account.accountList(context: context)) })
        Account.saveToIdentityStore(account: self)
    }

    // MARK: - AuthenticationServices

    private static func saveToIdentityStore(account: Account) {
        if #available(iOS 12.0, *) {
            ASCredentialIdentityStore.shared.getState { (state) in
                if !state.isEnabled {
                    return
                } else if state.supportsIncrementalUpdates {
                    let service = ASCredentialServiceIdentifier(identifier: account.site.url, type: ASCredentialServiceIdentifier.IdentifierType.URL)
                    let identity = ASPasswordCredentialIdentity(serviceIdentifier: service, user: account.username, recordIdentifier: account.id)
                    ASCredentialIdentityStore.shared.saveCredentialIdentities([identity], completion: nil)
                } else if let accounts = try? Account.all(context: nil) {
                    let identities = accounts.values.map { (account) -> ASPasswordCredentialIdentity in
                        let service = ASCredentialServiceIdentifier(identifier: account.site.url, type: ASCredentialServiceIdentifier.IdentifierType.URL)
                        return ASPasswordCredentialIdentity(serviceIdentifier: service, user: account.username, recordIdentifier: account.id)
                    }
                    ASCredentialIdentityStore.shared.saveCredentialIdentities(identities, completion: nil)
                }
            }
        }
    }

    private static func deleteFromToIdentityStore(account: Account) {
        if #available(iOS 12.0, *) {
            ASCredentialIdentityStore.shared.getState { (state) in
                if !state.isEnabled {
                    return
                } else if state.supportsIncrementalUpdates {
                    let service = ASCredentialServiceIdentifier(identifier: account.site.url, type: ASCredentialServiceIdentifier.IdentifierType.URL)
                    let identity = ASPasswordCredentialIdentity(serviceIdentifier: service, user: account.username, recordIdentifier: account.id)
                    ASCredentialIdentityStore.shared.removeCredentialIdentities([identity], completion: nil)
                } else {
                    ASCredentialIdentityStore.shared.removeAllCredentialIdentities({ (result, error) in
                        if let error = error {
                            Logger.shared.error("Error deleting credentials from identity store", error: error)
                        } else if result, let accounts = try? Account.all(context: nil) {
                            let identities = accounts.values.map { (account) -> ASPasswordCredentialIdentity in
                                let service = ASCredentialServiceIdentifier(identifier: account.site.url, type: ASCredentialServiceIdentifier.IdentifierType.URL)
                                return ASPasswordCredentialIdentity(serviceIdentifier: service, user: account.username, recordIdentifier: account.id)
                            }
                            ASCredentialIdentityStore.shared.saveCredentialIdentities(identities, completion: nil)
                        }
                    })
                }
            }
        }
    }

}
