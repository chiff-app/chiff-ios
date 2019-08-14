/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import Foundation
import OneTimePassword
import LocalAuthentication
import AuthenticationServices


/*
 * An account belongs to the user and can have one Site.
 */
struct SharedAccount: Account {
    let id: String
    var username: String
    var sites: [Site]
    var site: Site {
        return sites[0]
    }
    var passwordIndex: Int
    var passwordOffset: [Int]?
    var askToLogin: Bool?
    var askToChange: Bool? = false
    let enabled = true
    var synced = true

    static let keychainService: KeychainService = .sharedAccount

    init(username: String, sites: [Site], passwordIndex: Int = 0, key: Data, context: LAContext? = nil) throws {
        id = "\(sites[0].id)_\(username)".hash

        self.sites = sites
        self.username = username

        let passwordGenerator = PasswordGenerator(username: username, siteId: sites[0].id, ppd: sites[0].ppd, passwordSeed: key)
        let (generatedPassword, index) = try passwordGenerator.generate(index: passwordIndex, offset: passwordOffset)
        self.passwordIndex = index

        try save(password: generatedPassword)
    }

    init(id: String, username: String, sites: [Site], passwordIndex: Int, passwordOffset: [Int]?) {
        self.id = id
        self.username = username
        self.sites = sites
        self.passwordIndex = passwordIndex
        self.passwordOffset = passwordOffset
        self.askToLogin = true
    }

    mutating func update(accountData: Data, key: Data, context: LAContext? = nil) throws -> Bool {
        let decoder = JSONDecoder()
        let backupAccount = try decoder.decode(SharedBackupAccount.self, from: accountData)
        guard passwordIndex != backupAccount.passwordIndex || passwordOffset != backupAccount.passwordOffset || username != backupAccount.username || sites != backupAccount.sites else {
            return false
        }
        self.username = backupAccount.username
        self.sites = backupAccount.sites
        self.passwordOffset = backupAccount.passwordOffset

        let passwordGenerator = PasswordGenerator(username: self.username, siteId: site.id, ppd: site.ppd, passwordSeed: key)
        let (password, newIndex) = try passwordGenerator.generate(index: backupAccount.passwordIndex, offset: self.passwordOffset)
        self.passwordIndex = newIndex
        try update(secret: password.data)
        return true
    }

    func delete(completionHandler: @escaping (_ error: Error?) -> Void) {
        Keychain.shared.delete(id: id, service: SharedAccount.keychainService, reason: "Delete \(site.name)", authenticationType: .ifNeeded) { (context, error) in
            do {
                if let error = error {
                    throw error
                }
                try BackupManager.shared.deleteAccount(accountId: self.id)
                try BrowserSession.all().forEach({ $0.deleteAccount(accountId: self.id) })
                self.deleteFromToIdentityStore()
                Logger.shared.analytics(.accountDeleted)
                Properties.accountCount -= 1
                completionHandler(nil)
            } catch {
                Logger.shared.error("Error deleting accounts", error: error)
                return completionHandler(error)
            }
        }
    }

    func backup() throws {
        // Intentionally not implemented
    }

    // MARK: - Static functions

    static func save(accountData: Data, id: String, key: Data, context: LAContext?) throws {
        let decoder = JSONDecoder()
        let backupAccount = try decoder.decode(SharedBackupAccount.self, from: accountData)
        var account = SharedAccount(id: backupAccount.id,
                                  username: backupAccount.username,
                                  sites: backupAccount.sites,
                                  passwordIndex: backupAccount.passwordIndex,
                                  passwordOffset: backupAccount.passwordOffset)

        let passwordGenerator = PasswordGenerator(username: account.username, siteId: account.site.id, ppd: account.site.ppd, passwordSeed: key)
        let (password, index) = try passwordGenerator.generate(index: account.passwordIndex, offset: account.passwordOffset)
        account.passwordIndex = index
        // Remove token and save seperately in Keychain
        if let tokenSecret = backupAccount.tokenSecret, let tokenURL = backupAccount.tokenURL {
            let tokenData = tokenURL.absoluteString.data
            try Keychain.shared.save(id: id, service: .otp, secretData: tokenSecret, objectData: tokenData)
        }

        let data = try PropertyListEncoder().encode(account)

        try Keychain.shared.save(id: account.id, service: SharedAccount.keychainService, secretData: password.data, objectData: data)
        account.saveToIdentityStore()
    }

    private static func getSharedPasswordSeed() throws {
        
    }

}

extension SharedAccount: Codable {

    enum CodingKeys: CodingKey {
        case id
        case username
        case sites
        case passwordIndex
        case passwordOffset
        case askToLogin
        case askToChange
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try values.decode(String.self, forKey: .id)
        self.username = try values.decode(String.self, forKey: .username)
        self.sites = try values.decode([Site].self, forKey: .sites)
        self.passwordIndex = try values.decode(Int.self, forKey: .passwordIndex)
        self.passwordOffset = try values.decodeIfPresent([Int].self, forKey: .passwordOffset)
        self.askToLogin = try values.decodeIfPresent(Bool.self, forKey: .askToLogin)
    }

}
