/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import Foundation
import OneTimePassword
import LocalAuthentication
import AuthenticationServices
import CryptoKit


/*
 * An account belongs to the user and can have one Site.
 */
struct UserAccount: Account {

    let id: String
    var username: String
    var sites: [Site]
    var passwordIndex: Int
    var lastPasswordUpdateTryIndex: Int
    var passwordOffset: [Int]?
    var askToLogin: Bool?
    var askToChange: Bool?
    var enabled: Bool
    var version: Int
    var webAuthn: WebAuthn?

    var hasPassword: Bool {
        return passwordIndex >= 0
    }

    var site: Site {
        return sites[0]
    }

    var synced: Bool {
        do {
            return try Keychain.shared.isSynced(id: id, service: .account)
        } catch {
            Logger.shared.error("Error get account sync info", error: error)
        }
        return true // Defaults to true to prevent infinite cycles when an error occurs
    }

    var hasOtp: Bool {
        return Keychain.shared.has(id: id, service: .otp)
    }
    static let keychainService: KeychainService = .account

    init(username: String, sites: [Site], password: String?, rpId: String?, algorithms: [WebAuthnAlgorithm]?, context: LAContext? = nil) throws {
        id = "\(sites[0].id)_\(username)".hash

        self.sites = sites
        self.username = username
        self.enabled = false
        self.version = 1
        if let rpId = rpId, let algorithms = algorithms {
            self.webAuthn = try WebAuthn(id: rpId, algorithms: algorithms)
        }
        let keyPair = try webAuthn?.generateKeyPair(accountId: id, context: context)

        var generatedPassword = password
        if let password = password {
            let passwordGenerator = try PasswordGenerator(username: username, siteId: sites[0].id, ppd: sites[0].ppd, passwordSeed: Seed.getPasswordSeed(context: context))
            passwordOffset = try passwordGenerator.calculateOffset(index: 0, password: password)
            (generatedPassword, passwordIndex) = try passwordGenerator.generate(index: 0, offset: passwordOffset)
        } else if rpId != nil && algorithms != nil {
            // Initiate the account without a password
            self.passwordIndex = -1
            self.lastPasswordUpdateTryIndex = -1
        } else {
            let passwordGenerator = try PasswordGenerator(username: username, siteId: sites[0].id, ppd: sites[0].ppd, passwordSeed: Seed.getPasswordSeed(context: context))
            (generatedPassword, passwordIndex) = try passwordGenerator.generate(index: 0, offset: nil)
        }
        self.lastPasswordUpdateTryIndex = self.passwordIndex
        try save(password: generatedPassword, keyPair: keyPair)
    }

    init(id: String, username: String, sites: [Site], passwordIndex: Int, lastPasswordTryIndex: Int, passwordOffset: [Int]?, askToLogin: Bool?, askToChange: Bool?, enabled: Bool, version: Int, webAuthn: WebAuthn?) {
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
        self.webAuthn = webAuthn
    }


    mutating func nextPassword(context: LAContext? = nil) throws -> String {
        let offset: [Int]? = nil // Will it be possible to change to custom password?
        let passwordGenerator = try PasswordGenerator(username: username, siteId: site.id, ppd: site.ppd, passwordSeed: Seed.getPasswordSeed(context: context))
        let (newPassword, index) = try passwordGenerator.generate(index: lastPasswordUpdateTryIndex + 1, offset: offset)
        self.lastPasswordUpdateTryIndex = index
        let accountData = try PropertyListEncoder().encode(self)
        try Keychain.shared.update(id: id, service: .account, secretData: nil, objectData: accountData)
        return newPassword
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
        try BrowserSession.all().forEach({ try $0.updateAccountList(account: self) })
        saveToIdentityStore()
    }

    mutating func addSite(site: Site) throws {
        self.sites.append(site)
        try update(secret: nil)
    }

    mutating func removeSite(forIndex index: Int) throws {
        self.sites.remove(at: index)
        try update(secret: nil)
    }

    mutating func removeWebAuthn() throws {
        guard let webAuthn = webAuthn else {
            return
        }
        switch webAuthn.algorithm {
        case .EdDSA:
            try Keychain.shared.delete(id: id, service: .webauthn)
        case .ECDSA:
            try Keychain.shared.deleteKey(id: id)
        }
        self.webAuthn = nil
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
            let passwordGenerator = try PasswordGenerator(username: self.username, siteId: site.id, ppd: site.ppd, passwordSeed: Seed.getPasswordSeed(context: context))
            self.passwordOffset = try passwordGenerator.calculateOffset(index: newIndex, password: newPassword)
            self.passwordIndex = newIndex
            self.lastPasswordUpdateTryIndex = newIndex
        } else if let newUsername = newUsername, let oldPassword = try self.password(context: context) {
            let passwordGenerator = try PasswordGenerator(username: newUsername, siteId: site.id, ppd: site.ppd, passwordSeed: Seed.getPasswordSeed(context: context))
            self.passwordOffset = try passwordGenerator.calculateOffset(index: passwordIndex, password: oldPassword)
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

        let passwordGenerator = try PasswordGenerator(username: username, siteId: site.id, ppd: site.ppd, passwordSeed: Seed.getPasswordSeed(context: context))
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
                    try self.webAuthn?.delete(accountId: self.id)
                    try BackupManager.deleteAccount(accountId: self.id)
                    try BrowserSession.all().forEach({ $0.deleteAccount(accountId: self.id) })
                    self.deleteFromToIdentityStore()
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

    func backup() throws {
        var tokenURL: URL? = nil
        var tokenSecret: Data? = nil
        if let token = try oneTimePasswordToken() {
            tokenURL = try token.toURL()
            tokenSecret = token.generator.secret
        }
        let account = BackupUserAccount(account: self, tokenURL: tokenURL, tokenSecret: tokenSecret)
        BackupManager.backup(account: account) { result in
            do {
                try Keychain.shared.setSynced(value: result, id: account.id, service: .account)
            } catch {
                Logger.shared.error("Error setting account sync info", error: error)
            }
        }
    }

    func save(password: String?, keyPair: KeyPair?) throws {
        let accountData = try PropertyListEncoder().encode(self)
        try Keychain.shared.save(id: id, service: Self.keychainService, secretData: password?.data, objectData: accountData)
        if let keyPair = keyPair {
            try webAuthn?.save(accountId: self.id, keyPair: keyPair)
        }
        try backup()
        try BrowserSession.all().forEach({ try $0.updateAccountList(account: self) })
        saveToIdentityStore()
        Properties.accountCount += 1
    }


    // MARK: - WebAuthn functions

    mutating func webAuthnSign(challenge: String, rpId: String) throws -> (String, Int) {
        guard webAuthn != nil else {
            throw AccountError.noWebAuthn
        }
        let (signature, counter) = try webAuthn!.sign(accountId: self.id, challenge: challenge, rpId: rpId)
        try update(secret: nil)
        return (signature, counter)
    }

    func webAuthnPubKey() throws -> String {
        guard let webAuthn = webAuthn else {
            throw AccountError.noWebAuthn
        }
        return try webAuthn.pubKey(accountId: self.id)
    }


    // MARK: - Static functions


    static func restore(accountData: Data, id: String, context: LAContext?) throws {
        let decoder = JSONDecoder()
        let backupAccount = try decoder.decode(BackupUserAccount.self, from: accountData)
        let account = UserAccount(id: backupAccount.id,
                              username: backupAccount.username,
                              sites: backupAccount.sites,
                              passwordIndex: backupAccount.passwordIndex,
                              lastPasswordTryIndex: backupAccount.lastPasswordUpdateTryIndex,
                              passwordOffset: backupAccount.passwordOffset,
                              askToLogin: backupAccount.askToLogin,
                              askToChange: backupAccount.askToChange,
                              enabled: backupAccount.enabled,
                              version: backupAccount.version,
                              webAuthn: backupAccount.webAuthn)
        assert(account.id == id, "Account restoring went wrong. Different id")

        var password: String? = nil
        if account.passwordIndex >= 0 {
            let passwordGenerator = try PasswordGenerator(username: account.username, siteId: account.site.id, ppd: account.site.ppd, passwordSeed: Seed.getPasswordSeed(context: context))
            (password, _) = try passwordGenerator.generate(index: account.passwordIndex, offset: account.passwordOffset)
        }

        // Remove token and save seperately in Keychain
        if let tokenSecret = backupAccount.tokenSecret, let tokenURL = backupAccount.tokenURL {
            let tokenData = tokenURL.absoluteString.data
            try Keychain.shared.save(id: id, service: .otp, secretData: tokenSecret, objectData: tokenData)
        }

        // Webauthn
        if let webAuthn = account.webAuthn {
            let keyPair = try webAuthn.generateKeyPair(accountId: account.id, context: context)
            switch webAuthn.algorithm {
            case .EdDSA:
                try Keychain.shared.save(id: id, service: .webauthn, secretData: keyPair.privKey, objectData: keyPair.pubKey)
            case .ECDSA:
                guard #available(iOS 13.0, *) else {
                    throw WebAuthnError.notSupported
                }
                let privKey = try P256.Signing.PrivateKey(rawRepresentation: keyPair.privKey)
                try Keychain.shared.saveKey(id: id, key: privKey)
            }
        }

        let data = try PropertyListEncoder().encode(account)

        try Keychain.shared.save(id: account.id, service: .account, secretData: password?.data, objectData: data)
        account.saveToIdentityStore()
    }

}

extension UserAccount: Codable {

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
        case webAuthn
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
        self.webAuthn = try values.decodeIfPresent(WebAuthn.self, forKey: .webAuthn)
    }

}


// Version migration
extension UserAccount {

    mutating func updateVersion(context: LAContext?) {
        guard version == 0 else {
            return
        }
        do {
            guard let password = try password() else {
                throw KeychainError.notFound
            }
            let generator = PasswordGenerator(username: username, siteId: site.id, ppd: site.ppd, passwordSeed: try Seed.getPasswordSeed(context: context), version: 1)
            passwordOffset = try generator.calculateOffset(index: passwordIndex, password: password)
            version = 1
            let accountData = try PropertyListEncoder().encode(self)
            try Keychain.shared.update(id: id, service: .account, secretData: nil, objectData: accountData, context: nil)
            try backup()
        } catch {
            Logger.shared.warning("Error updating account version", error: error, userInfo: nil)
        }

    }
}

