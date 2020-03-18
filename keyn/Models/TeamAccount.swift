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
struct TeamAccount: Account {
    
    let id: String
    var username: String
    var sites: [Site]
    var passwordIndex: Int
    var passwordOffset: [Int]?
    var askToLogin: Bool?
    var askToChange: Bool? = false
    let enabled = true
    let sessionPubKey: String
    var synced = true
    var version: Int
    var timesUsed: Int
    var lastTimeUsed: Date?

    var site: Site {
        return sites.first!
    }
    var hasPassword: Bool {
        return true
    }

    static let keychainService: KeychainService = .sharedAccount

    init(id: String, username: String, sites: [Site], passwordIndex: Int, passwordOffset: [Int]?, version: Int, sessionPubKey: String) {
        self.id = id
        self.username = username
        self.sites = sites
        self.passwordIndex = passwordIndex
        self.passwordOffset = passwordOffset
        self.askToLogin = true
        self.sessionPubKey = sessionPubKey
        self.version = version
        self.timesUsed = 0
    }

    mutating func update(accountData: Data, key: Data, context: LAContext? = nil) throws -> Bool {
        let decoder = JSONDecoder()
        let backupAccount = try decoder.decode(BackupTeamAccount.self, from: accountData)
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

    func delete(completionHandler: @escaping (Result<Void, Error>) -> Void) {
        Keychain.shared.delete(id: id, service: TeamAccount.keychainService, reason: "Delete \(site.name)", authenticationType: .ifNeeded) { (result) in
            do {
                switch result {
                case .success(_):
                    try BrowserSession.all().forEach({ $0.deleteAccount(accountId: self.id) })
                    self.deleteFromToIdentityStore()
                    completionHandler(.success(()))
                case .failure(let error): throw error
                }
            } catch {
                Logger.shared.error("Error deleting accounts", error: error)
                return completionHandler(.failure(error))
            }
        }
    }

    func delete() throws {
        try Keychain.shared.delete(id: id, service: TeamAccount.keychainService)
        try BrowserSession.all().forEach({ $0.deleteAccount(accountId: id) })
        self.deleteFromToIdentityStore()
    }

    func backup() throws {
        // Intentionally not implemented
    }

    func save(password: String, sessionPubKey: String) throws {
        let accountData = try PropertyListEncoder().encode(self)
        try Keychain.shared.save(id: id, service: Self.keychainService, secretData: password.data, objectData: accountData, label: sessionPubKey)
        try backup()
        try BrowserSession.all().forEach({ try $0.updateAccountList(account: self) })
        saveToIdentityStore()
    }

    // MARK: - Static functions

    static func create(accountData: Data, id: String, key: Data, context: LAContext?, sessionPubKey: String) throws {
        let decoder = JSONDecoder()
        let backupAccount = try decoder.decode(BackupTeamAccount.self, from: accountData)
        var account = TeamAccount(id: backupAccount.id,
                                  username: backupAccount.username,
                                  sites: backupAccount.sites,
                                  passwordIndex: backupAccount.passwordIndex,
                                  passwordOffset: backupAccount.passwordOffset,
                                  version: 1,
                                  sessionPubKey: sessionPubKey)

        let passwordGenerator = PasswordGenerator(username: account.username, siteId: account.site.id, ppd: account.site.ppd, passwordSeed: key)
        let (password, index) = try passwordGenerator.generate(index: account.passwordIndex, offset: account.passwordOffset)
        account.passwordIndex = index
        // Remove token and save seperately in Keychain
        if let tokenSecret = backupAccount.tokenSecret, let tokenURL = backupAccount.tokenURL {
            let tokenData = tokenURL.absoluteString.data
            try Keychain.shared.save(id: id, service: .otp, secretData: tokenSecret, objectData: tokenData)
        }

        try account.save(password: password, sessionPubKey: sessionPubKey)
    }

    static func deleteAll(for sessionPubKey: String) {
        Keychain.shared.deleteAll(service: Self.keychainService, label: sessionPubKey)
        NotificationCenter.default.post(name: .sharedAccountsChanged, object: nil)
        if #available(iOS 12.0, *) {
            Properties.reloadAccounts = true
        }
    }

}

extension TeamAccount: Codable {

    enum CodingKeys: CodingKey {
        case id
        case username
        case sites
        case passwordIndex
        case passwordOffset
        case askToLogin
        case askToChange
        case sessionPubKey
        case version
        case timesUsed
        case lastTimeUsed
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try values.decode(String.self, forKey: .id)
        self.username = try values.decode(String.self, forKey: .username)
        self.sites = try values.decode([Site].self, forKey: .sites)
        self.passwordIndex = try values.decode(Int.self, forKey: .passwordIndex)
        self.passwordOffset = try values.decodeIfPresent([Int].self, forKey: .passwordOffset)
        self.askToLogin = try values.decodeIfPresent(Bool.self, forKey: .askToLogin)
        self.version = try values.decodeIfPresent(Int.self, forKey: .version) ?? 0
        self.sessionPubKey = try values.decode(String.self, forKey: .sessionPubKey)
        self.timesUsed = try values.decodeIfPresent(Int.self, forKey: .timesUsed) ?? 0
        self.lastTimeUsed = try values.decodeIfPresent(Date?.self, forKey: .lastTimeUsed) ?? nil
    }

}
