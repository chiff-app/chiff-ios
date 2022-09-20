//
//  SharedAccount.swift
//  ChiffCore
//
//  Copyright: see LICENSE.md
//

import Foundation
import OneTimePassword
import LocalAuthentication
import AuthenticationServices
import PromiseKit

/// `SharedAccount`s are managed by a `TeamSession`.
public struct SharedAccount: Account, Identity {
    public let id: String
    public var username: String
    public var sites: [Site]
    public var passwordIndex: Int
    public var passwordOffset: [Int]?
    public var askToLogin: Bool?
    public var askToChange: Bool? = false
    public let sessionId: String
    public var version: Int
    public var timesUsed: Int
    public var lastTimeUsed: Date?

    public var site: Site {
        return sites.first!
    }
    public var hasPassword: Bool {
        return true
    }

    public static let keychainService: KeychainService = .sharedAccount()
    public static let otpService: KeychainService = .sharedAccount(attribute: .otp)
    public static let notesService: KeychainService = .sharedAccount(attribute: .notes)
    public static let webAuthnService: KeychainService = .sharedAccount(attribute: .webauthn)

    init(id: String, username: String, sites: [Site], passwordIndex: Int, passwordOffset: [Int]?, version: Int, sessionId: String) {
        self.id = id
        self.username = username
        self.sites = sites
        self.passwordIndex = passwordIndex
        self.passwordOffset = passwordOffset
        self.askToLogin = true
        self.sessionId = sessionId
        self.version = version
        self.timesUsed = 0
    }

    /// Updated the local account to reflect the remote data.
    /// - Parameters:
    ///   - accountData: The remote account data.
    ///   - key: The seed from the `TeamSession` that is used to generate the passwords.
    ///   - context: Optionally, an authenticated `LAContext`.
    /// - Throws: Keychain and decoding related errors.
    /// - Returns: A boolean whether something has been updated.
    public mutating func sync(accountData: Data, key: Data, context: LAContext? = nil) throws -> Bool {
        let decoder = JSONDecoder()
        let backupAccount = try decoder.decode(BackupSharedAccount.self, from: accountData)
        let notesChanged = try updateNotes(notes: backupAccount.notes)
        let otpChanged = try updateToken(tokenSecret: backupAccount.tokenSecret, tokenURL: backupAccount.tokenURL)
        guard notesChanged
                || otpChanged
                || passwordIndex != backupAccount.passwordIndex
                || passwordOffset != backupAccount.passwordOffset
                || username != backupAccount.username
                || sites != backupAccount.sites else {
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

    // Documentation in protocol
    public func delete() -> Promise<Void> {
        do {
            try Keychain.shared.delete(id: self.id, service: .sharedAccount())
            try? Keychain.shared.delete(id: self.id, service: Self.notesService)
            self.deleteFromToIdentityStore()
            return when(fulfilled: try BrowserSession.all().map({ $0.deleteAccount(accountId: self.id) })).log("Error deleting accounts")
        } catch {
            return Promise(error: error)
        }
    }

    // Documentation in protocol
    public func update(secret: Data?, backup: Bool = false) throws {
        let accountData = try PropertyListEncoder().encode(self as Self)
        try Keychain.shared.update(id: id, service: Self.keychainService, secretData: secret, objectData: accountData, context: nil)
        try BrowserSession.all().forEach({ _ = try $0.updateSessionAccount(account: SessionAccount(account: self as Self)) })
        saveToIdentityStore()
    }

    // MARK: - Static functions

    /// Create a new `SharedAccount`.
    /// - Parameters:
    ///   - accountData: The acount data.
    ///   - id: The account identifier
    ///   - key: The seed used to generate the password.
    ///   - context: Optionally, an authenticated `LAContext` object.
    ///   - sessionId: The `TeamSession` that manages this account.
    /// - Throws: Keychain, encoding, or password generation errors.
    static func create(accountData: Data, id: String, key: Data, context: LAContext?, sessionId: String) throws {
        let decoder = JSONDecoder()
        let backupAccount = try decoder.decode(BackupSharedAccount.self, from: accountData)
        var account = SharedAccount(id: backupAccount.id,
                                  username: backupAccount.username,
                                  sites: backupAccount.sites,
                                  passwordIndex: backupAccount.passwordIndex,
                                  passwordOffset: backupAccount.passwordOffset,
                                  version: 1,
                                  sessionId: sessionId)

        let passwordGenerator = PasswordGenerator(username: account.username, siteId: account.site.id, ppd: account.site.ppd, passwordSeed: key)
        let (password, index) = try passwordGenerator.generate(index: account.passwordIndex, offset: account.passwordOffset)
        account.passwordIndex = index
        // Remove token and save seperately in Keychain
        if let tokenSecret = backupAccount.tokenSecret, let tokenURL = backupAccount.tokenURL {
            let tokenData = tokenURL.absoluteString.data
            try Keychain.shared.save(id: id, service: Self.otpService, secretData: tokenSecret, objectData: tokenData, label: sessionId)
        }
        if let notes = backupAccount.notes {
            try Keychain.shared.save(id: id, service: Self.notesService, secretData: notes.data, objectData: nil, label: sessionId)
        }
        try account.save(password: password, sessionId: sessionId)
    }

    /// Delete all `SharedAccount`s for a `TeamSession`.
    /// - Parameter sessionId: The `TeamSession` id.
    static func deleteAll(for sessionId: String) {
        if let accounts = try? all(context: nil, label: sessionId), let sessions = try? BrowserSession.all() {
            for id in accounts.keys {
                sessions.forEach({ _ = $0.deleteAccount(accountId: id) })
            }
        }
        Keychain.shared.deleteAll(service: .sharedAccount(), label: sessionId)
        Keychain.shared.deleteAll(service: .sharedAccount(attribute: .notes), label: sessionId)
        Keychain.shared.deleteAll(service: .sharedAccount(attribute: .otp), label: sessionId)
        NotificationCenter.default.postMain(name: .sharedAccountsChanged, object: nil)
        if #available(iOS 12.0, *) {
            Properties.reloadAccounts = true
        }
    }

    // MARK: - Private functions

    private func save(password: String, sessionId: String) throws {
        let accountData = try PropertyListEncoder().encode(self)
        try Keychain.shared.save(id: id, service: Self.keychainService, secretData: password.data, objectData: accountData, label: sessionId)
        try BrowserSession.all().forEach({ _ = try $0.updateSessionAccount(account: SessionAccount(account: self)) })
        saveToIdentityStore()
    }

    private func updateNotes(notes: String?) throws -> Bool {
        guard let notes = notes else {
            return false
        }
        if Keychain.shared.has(id: id, service: Self.notesService) {
            if notes.isEmpty {
                try Keychain.shared.delete(id: id, service: Self.notesService)
            } else {
                try Keychain.shared.update(id: id, service: Self.notesService, secretData: notes.data, objectData: nil)
            }
        } else if !notes.isEmpty {
            try Keychain.shared.save(id: id, service: Self.notesService, secretData: notes.data, objectData: nil)
        }
        return true
    }

    private func updateToken(tokenSecret: Data?, tokenURL: URL?) throws -> Bool {
        if let tokenSecret = tokenSecret, let tokenURL = tokenURL {
            let tokenData = tokenURL.absoluteString.data
            if let currentToken = try oneTimePasswordToken() {
                guard try currentToken.generator.secret != tokenSecret || currentToken.toURL() != tokenURL else {
                    return false
                }
                // The token has been updated
                try Keychain.shared.update(id: id, service: Self.otpService, secretData: tokenSecret, objectData: tokenData)
                return true
            } else {
                // Save token
                try Keychain.shared.save(id: id, service: Self.otpService, secretData: tokenSecret, objectData: tokenData, label: sessionId)
                return true
            }
        } else if Keychain.shared.has(id: id, service: Self.otpService) {
            try Keychain.shared.delete(id: id, service: Self.otpService)
            return true
        } else {
            return false
        }
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
        case sessionId
        case version
        case timesUsed
        case lastTimeUsed
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try values.decode(String.self, forKey: .id)
        self.username = try values.decode(String.self, forKey: .username)
        self.sites = try values.decode([Site].self, forKey: .sites)
        self.passwordIndex = try values.decode(Int.self, forKey: .passwordIndex)
        self.passwordOffset = try values.decodeIfPresent([Int].self, forKey: .passwordOffset)
        self.askToLogin = try values.decodeIfPresent(Bool.self, forKey: .askToLogin)
        self.version = try values.decodeIfPresent(Int.self, forKey: .version) ?? 0
        self.sessionId = try values.decode(String.self, forKey: .sessionId)
        self.timesUsed = try values.decodeIfPresent(Int.self, forKey: .timesUsed) ?? 0
        self.lastTimeUsed = try values.decodeIfPresent(Date.self, forKey: .lastTimeUsed)
    }

}
