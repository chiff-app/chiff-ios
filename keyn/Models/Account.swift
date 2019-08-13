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
    case passwordGeneration
}

/*
 * An account belongs to the user and can have one Site.
 */
struct Account {

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
    var enabled: Bool
    var version: Int

    var synced: Bool {
        do {
            return try Keychain.shared.isSynced(id: id, service: .account)
        } catch {
            Logger.shared.error("Error get account sync info", error: error)
            return true // Defaults to true to prevent infinite cycles when an error occurs
        }
    }

    var hasOtp: Bool {
        return Keychain.shared.has(id: id, service: .otp)
    }

    init(username: String, sites: [Site], passwordIndex: Int = 0, password: String?, context: LAContext? = nil) throws {
        id = "\(sites[0].id)_\(username)".hash

        self.sites = sites
        self.username = username
        self.enabled = false
        self.version = 1

        let passwordGenerator = PasswordGenerator(username: username, siteId: sites[0].id, ppd: sites[0].ppd, context: context, version: version)
        if let password = password {
            passwordOffset = try passwordGenerator.calculateOffset(index: passwordIndex, password: password)
        } else {
            askToChange = false
        }
        
        let (generatedPassword, index) = try passwordGenerator.generate(index: passwordIndex, offset: passwordOffset)
        self.passwordIndex = index  
        self.lastPasswordUpdateTryIndex = index

        try save(password: generatedPassword)
    }

    init(id: String, username: String, sites: [Site], passwordIndex: Int, lastPasswordTryIndex: Int, passwordOffset: [Int]?, askToLogin: Bool?, askToChange: Bool?, enabled: Bool, version: Int) {
        self.id = id
        self.username = username
        self.sites = sites
        self.passwordIndex = passwordIndex
        self.lastPasswordUpdateTryIndex = lastPasswordTryIndex
        self.passwordOffset = passwordOffset
        self.askToLogin = askToLogin
        self.askToChange = askToChange
        self.enabled = enabled
        self.version = version
    }

    mutating func nextPassword(context: LAContext? = nil) throws -> String {
        let offset: [Int]? = nil // Will it be possible to change to custom password?
        let passwordGenerator = PasswordGenerator(username: username, siteId: site.id, ppd: site.ppd, context: context, version: version)
        let (newPassword, index) = try passwordGenerator.generate(index: lastPasswordUpdateTryIndex + 1, offset: offset)
        self.lastPasswordUpdateTryIndex = index
        let accountData = try PropertyListEncoder().encode(self)
        try Keychain.shared.update(id: id, service: .account, secretData: nil, objectData: accountData)
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

    mutating func setOtp(token: Token) throws {
        let secret = token.generator.secret
        let tokenData = try token.toURL().absoluteString.data

        if self.hasOtp {
            try Keychain.shared.update(id: id, service: .otp, secretData: secret, objectData: tokenData)
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
        try update(secret: nil)
    }

    mutating func removeSite(forIndex index: Int) throws {
        self.sites.remove(at: index)
        try update(secret: nil)
    }

    mutating func updateSite(url: String, forIndex index: Int) throws {
        self.sites[index].url = url
        try update(secret: nil)
    }
    
    mutating func update(username newUsername: String?, password newPassword: String?, siteName: String?, url: String?, askToLogin: Bool?, askToChange: Bool?, enabled: Bool?, context: LAContext? = nil) throws {
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
        if let enabled = enabled {
            self.enabled = enabled
        }

        if let newPassword = newPassword {
            if askToChange == nil {
                self.askToChange = true
            }
            let newIndex = passwordIndex + 1
            let passwordGenerator = PasswordGenerator(username: self.username, siteId: site.id, ppd: site.ppd, context: context, version: version)
            self.passwordOffset = try passwordGenerator.calculateOffset(index: newIndex, password: newPassword)
            self.passwordIndex = newIndex
            self.lastPasswordUpdateTryIndex = newIndex
        } else if let newUsername = newUsername {
            let passwordGenerator = PasswordGenerator(username: newUsername, siteId: site.id, ppd: site.ppd, context: context, version: version)
            self.passwordOffset = try passwordGenerator.calculateOffset(index: passwordIndex, password: try self.password(context: context))
        }

        try update(secret: newPassword?.data)
    }

    /*
     * After saving a new (generated) password in the browser we place a message
     * on the queue stating that it succeeded. We can then call this function to
     * confirm the new password and store it in the account.
     */
    mutating func updatePasswordAfterConfirmation(context: LAContext?) throws {
        let offset: [Int]? = nil // Will it be possible to change to custom password?

        let passwordGenerator = PasswordGenerator(username: username, siteId: site.id, ppd: site.ppd, context: context, version: version)
        let (newPassword, newIndex) = try passwordGenerator.generate(index: lastPasswordUpdateTryIndex, offset: offset)

        self.passwordIndex = newIndex
        self.lastPasswordUpdateTryIndex = newIndex
        passwordOffset = offset
        askToChange = false

        let accountData = try PropertyListEncoder().encode(self)
        try Keychain.shared.update(id: id, service: .account, secretData: newPassword.data, objectData: accountData)
        try backup()
        try BrowserSession.all().forEach({ try $0.updateAccountList(account: self) })
    }

    func delete(completionHandler: @escaping (Result<Void, Error>) -> Void) {
        Keychain.shared.delete(id: id, service: .account, reason: "Delete \(site.name)", authenticationType: .ifNeeded) { (result) in
            do {
                switch result {
                case .success(_):
                    try BackupManager.shared.deleteAccount(accountId: self.id)
                    try BrowserSession.all().forEach({ $0.deleteAccount(accountId: self.id) })
                    Account.deleteFromToIdentityStore(account: self)
                    Logger.shared.analytics(.accountDeleted)
                    Properties.accountCount -= 1
                    completionHandler(.success(()))
                case .failure(let error): throw error
                }
            } catch {
                Logger.shared.error("Error deleting accounts", error: error)
                return completionHandler(.failure(error))
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

    func password(reason: String, context: LAContext? = nil, type: AuthenticationType, completionHandler: @escaping (Result<String, Error>) -> Void) {
        Keychain.shared.get(id: id, service: .account, reason: reason, with: context, authenticationType: type) { (result) in
            switch result {
            case .success(let data):
                guard let password = String(data: data, encoding: .utf8) else {
                    return completionHandler(.failure(CodingError.stringEncoding))
                }
                completionHandler(.success(password))
            case .failure(let error): completionHandler(.failure(error))
            }
        }
    }

    // MARK: - Static

    /*
     * This function must always be called to load the accounts
     * but is delayed because it coincides with when touchID is asked.
     */
    static func all(context: LAContext?, sync: Bool = false) throws -> [String: Account] {
        guard let dataArray = try Keychain.shared.all(service: .account, context: context) else {
            return [:]
        }
        Properties.accountCount = dataArray.count
        let decoder = PropertyListDecoder()

        return Dictionary(uniqueKeysWithValues: try dataArray.map { (dict) in
            guard let accountData = dict[kSecAttrGeneric as String] as? Data else {
                throw CodingError.unexpectedData
            }
            var account = try decoder.decode(Account.self, from: accountData)
            if sync {
                if account.version == 0 {
                    account.updateVersion(context: context)
                } else if !account.synced {
                    try? account.backup()
                }
            }
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
    
    static func save(accountData: Data, id: String, context: LAContext?) throws {
        let decoder = JSONDecoder()
        let backupAccount = try decoder.decode(BackupAccount.self, from: accountData)
        let account = Account(id: backupAccount.id,
                              username: backupAccount.username,
                              sites: backupAccount.sites,
                              passwordIndex: backupAccount.passwordIndex,
                              lastPasswordTryIndex: backupAccount.lastPasswordUpdateTryIndex,
                              passwordOffset: backupAccount.passwordOffset,
                              askToLogin: backupAccount.askToLogin,
                              askToChange: backupAccount.askToChange,
                              enabled: backupAccount.enabled,
                              version: backupAccount.version)
        assert(account.id == id, "Account restoring went wrong. Different id")

        let passwordGenerator = PasswordGenerator(username: account.username, siteId: account.site.id, ppd: account.site.ppd, context: context, version: account.version)
        let (password, index) = try passwordGenerator.generate(index: account.passwordIndex, offset: account.passwordOffset)
        
        assert(index == account.passwordIndex, "Password wasn't properly generated. Different index")

        // Remove token and save seperately in Keychain
        if let tokenSecret = backupAccount.tokenSecret, let tokenURL = backupAccount.tokenURL {
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

    private func update(secret: Data?) throws {
        let accountData = try PropertyListEncoder().encode(self)
        try Keychain.shared.update(id: id, service: .account, secretData: secret, objectData: accountData, context: nil)
        try backup()
        try BrowserSession.all().forEach({ try $0.updateAccountList(account: self) })
        Account.saveToIdentityStore(account: self)
    }

    private func save(password: String) throws {
        let accountData = try PropertyListEncoder().encode(self)
        try Keychain.shared.save(id: id, service: .account, secretData: password.data, objectData: accountData)
        try backup()
        try BrowserSession.all().forEach({ try $0.updateAccountList(account: self) })
        Account.saveToIdentityStore(account: self)
        Properties.accountCount += 1
    }

    private func backup() throws {
        var tokenURL: URL? = nil
        var tokenSecret: Data? = nil
        if let token = try oneTimePasswordToken() {
            tokenURL = try token.toURL()
            tokenSecret = token.generator.secret
        }
        let account = BackupAccount(account: self, tokenURL: tokenURL, tokenSecret: tokenSecret)
        BackupManager.shared.backup(account: account) { result in
            do {
                try Keychain.shared.setSynced(value: result, id: account.id, service: .account)
            } catch {
                Logger.shared.error("Error setting account sync info", error: error)
            }
        }
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

extension Account: Codable {

    enum CodingKeys: CodingKey {
        case id
        case username
        case sites
        case passwordIndex
        case lastPasswordUpdateTryIndex
        case passwordOffset
        case askToLogin
        case askToChange
        case enabled
        case version
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try values.decode(String.self, forKey: .id)
        self.username = try values.decode(String.self, forKey: .username)
        self.sites = try values.decode([Site].self, forKey: .sites)
        self.passwordIndex = try values.decode(Int.self, forKey: .passwordIndex)
        self.lastPasswordUpdateTryIndex = try values.decode(Int.self, forKey: .lastPasswordUpdateTryIndex)
        self.passwordOffset = try values.decodeIfPresent([Int].self, forKey: .passwordOffset)
        self.askToLogin = try values.decodeIfPresent(Bool.self, forKey: .askToLogin)
        self.askToChange = try values.decodeIfPresent(Bool.self, forKey: .askToChange)
        self.enabled = try values.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
        self.version = try values.decodeIfPresent(Int.self, forKey: .version) ?? 0
    }

}

// Version migration
extension Account {

    mutating func updateVersion(context: LAContext?) {
        guard version == 0 else {
            return
        }
        do {
            let generator = PasswordGenerator(username: username, siteId: site.id, ppd: site.ppd, context: context, version: 1)
            passwordOffset = try generator.calculateOffset(index: passwordIndex, password: password())
            version = 1
            let accountData = try PropertyListEncoder().encode(self)
            try Keychain.shared.update(id: id, service: .account, secretData: nil, objectData: accountData, context: nil)
            try backup()
        } catch {
            Logger.shared.warning("Error updating account version", error: error, userInfo: nil)
        }

    }

}
