//
//  UserAccount+Restorable.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import Foundation
import LocalAuthentication
import CryptoKit
import PromiseKit

extension UserAccount: Syncable {

    typealias BackupType = BackupUserAccount

    static var syncEndpoint: SyncEndpoint {
        return .accounts
    }

    // Documentation in protocol.
    static func all(context: LAContext?) throws -> [String: UserAccount] {
        // If label is not provided, this method tries to call itself and crashes..
        return try all(context: context, label: nil)
    }

    // Documentation in protocol.
    static func create(backupObject: BackupUserAccount, context: LAContext?) throws {
        _ = try UserAccount(backupObject: backupObject, context: context)
    }

    // Documentation in protocol.
    static func notifyObservers() {
        NotificationCenter.default.postMain(name: .accountsLoaded, object: nil)
    }

    /// Backup multiple accounts at once.
    /// - Parameter accounts: A dictionary of tuples that consist of an account and the notes.
    static func backup(accounts: [String: (UserAccount, String?)]) -> Promise<Void> {
        do {
            let encryptedAccounts: [String: String] = try accounts.mapValues {
                let data = try JSONEncoder().encode(BackupUserAccount(account: $0.0, tokenURL: nil, tokenSecret: nil, notes: $0.1))
                return try Crypto.shared.encryptSymmetric(data.compress() ?? data, secretKey: try encryptionKey()).base64
            }
            let message: [String: Any] = [
                "httpMethod": APIMethod.put.rawValue,
                "timestamp": String(Date.now),
                "accounts": encryptedAccounts
            ]
            let jsonData = try JSONSerialization.data(withJSONObject: message, options: [])
            let signature = try Crypto.shared.signature(message: jsonData, privKey: try privateKey()).base64
            return firstly {
                API.shared.request(path: "users/\(try publicKey())/accounts", method: .put, signature: signature, body: jsonData, parameters: nil)
            }.asVoid().log("BackupManager cannot write bulk user accounts.")
        } catch {
            return Promise(error: error)
        }
    }

    // MARK: - Init

    /// Intialize a `UserAccount` from backup data.
    /// - Parameters:
    ///   - backupObject: The backup data object.
    ///   - context: Optionally, an authenticated `LAContext` object.
    /// - Throws: Keychain, decoding or password generating errors.
    init(backupObject: BackupUserAccount, context: LAContext?) throws {
        id = backupObject.id
        username = backupObject.username
        sites = backupObject.sites
        passwordIndex = backupObject.passwordIndex
        lastPasswordUpdateTryIndex = backupObject.passwordIndex
        passwordOffset = backupObject.passwordOffset
        askToLogin = backupObject.askToLogin
        askToChange = backupObject.askToChange
        version = backupObject.version
        webAuthn = backupObject.webAuthn
        timesUsed = 0
        lastTimeUsed = nil
        lastChange = backupObject.lastChange

        var password: String?
        if passwordIndex >= 0 {
            let passwordGenerator = try PasswordGenerator(username: username, siteId: site.id, ppd: site.ppd, passwordSeed: Seed.getPasswordSeed(context: context))
            (password, _) = try passwordGenerator.generate(index: passwordIndex, offset: passwordOffset)
        }

        // Remove token and save seperately in Keychain
        if let tokenSecret = backupObject.tokenSecret, let tokenURL = backupObject.tokenURL {
            let tokenData = tokenURL.absoluteString.data
            try Keychain.shared.save(id: id, service: .account(attribute: .otp), secretData: tokenSecret, objectData: tokenData)
        }

        // Webauthn
        if let webAuthn = webAuthn {
            try saveWebAuthn(webAuthn: webAuthn, context: context)
        }

        if let notes = backupObject.notes, !notes.isEmpty {
            try Keychain.shared.save(id: id, service: .account(attribute: .notes), secretData: notes.data, objectData: nil)
        }

        let data = try PropertyListEncoder().encode(self)
        try Keychain.shared.save(id: id, service: Self.keychainService, secretData: password?.data, objectData: data)
        saveToIdentityStore()
    }

    // Documentation in protocol
    func backup() throws -> Promise<Void> {
        var tokenURL: URL?
        var tokenSecret: Data?
        if let token = try oneTimePasswordToken() {
            tokenURL = try token.toURL()
            tokenSecret = token.generator.secret
        }
        return firstly {
            sendData(item: BackupUserAccount(account: self, tokenURL: tokenURL, tokenSecret: tokenSecret, notes: try notes()))
        }.log("Error setting account sync info")
    }

    // Documentation in protocol.
    mutating func update(with backupObject: BackupUserAccount, context: LAContext? = nil) throws -> Bool {
        // Attributes
        var (changed, updatePassword) = updateAttributes(with: backupObject)

        // Password
        var password: String?
        var newIndex: Int!
        if updatePassword {
            let passwordGenerator = PasswordGenerator(username: self.username, siteId: site.id, ppd: site.ppd, passwordSeed: try Seed.getPasswordSeed(context: context))
            (password, newIndex) = try passwordGenerator.generate(index: backupObject.passwordIndex, offset: self.passwordOffset)
            guard self.passwordIndex == newIndex else {
                throw AccountError.passwordGeneration
            }
        }

        // OTP
        if try updateToken(with: backupObject, context: context) {
            changed = true
        }

        // Webauthn
        if try updateWebAuthn(with: backupObject, context: context) {
            changed = true
        }

        // Notes
        if try updateNotes(with: backupObject, context: context) {
            changed = true
        }

        try update(secret: password?.data, backup: false)
        return changed
    }

    // MARK: - Private functinos

    private mutating func updateAttributes(with backupAccount: BackupUserAccount) -> (Bool, Bool) {
        var updatePassword = false
        var changed = false
        self.lastChange = backupAccount.lastChange
        if backupAccount.username != username {
            self.username = backupAccount.username
            updatePassword = true
            changed = true
        }
        if backupAccount.sites != sites {
            if self.site != backupAccount.site {
                updatePassword = true
            }
            changed = true
            self.sites = backupAccount.sites
        }
        if backupAccount.passwordIndex != passwordIndex {
            self.passwordIndex = backupAccount.passwordIndex
            updatePassword = true
            changed = true
        }
        if backupAccount.passwordOffset != passwordOffset {
            self.passwordOffset = backupAccount.passwordOffset
            updatePassword = true
            changed = true
        }
        if backupAccount.askToLogin != askToLogin {
            self.askToLogin = backupAccount.askToLogin
            changed = true
        }
        if backupAccount.askToChange != askToChange {
            self.askToChange = backupAccount.askToChange
            changed = true
        }
        if backupAccount.version != version {
            self.version = backupAccount.version
            changed = true
        }
        return (changed, updatePassword)
    }

    private mutating func updateToken(with backupAccount: BackupUserAccount, context: LAContext?) throws -> Bool {
        var tokenURL: URL?
        var tokenSecret: Data?
        if let token = try oneTimePasswordToken() {
            tokenURL = try token.toURL()
            tokenSecret = token.generator.secret
        }
        guard tokenSecret != backupAccount.tokenSecret || tokenURL != backupAccount.tokenURL else {
            return false
        }
        if let newTokenSecret = backupAccount.tokenSecret, let newTokenURLData = backupAccount.tokenURL?.absoluteString.data {
            if tokenSecret != nil {
                try Keychain.shared.update(id: id, service: .account(attribute: .otp), secretData: newTokenSecret, objectData: newTokenURLData)
            } else {
                try Keychain.shared.save(id: id, service: .account(attribute: .otp), secretData: newTokenSecret, objectData: newTokenURLData)
            }
        } else if tokenSecret != nil {
            try Keychain.shared.delete(id: id, service: .account(attribute: .otp))
        }
        return true
    }

    private mutating func updateWebAuthn(with backupAccount: BackupUserAccount, context: LAContext?) throws -> Bool {
        guard backupAccount.webAuthn != webAuthn else {
            return false
        }
        if let webAuthn = backupAccount.webAuthn {
            if self.webAuthn == nil {
                /*  The WebAuthn specification doesn't allow updating the keys, so doesn't make sense to support it here.
                 *  Only create the keys if they don't exist.
                 */
                try saveWebAuthn(webAuthn: webAuthn, context: context)
            }
            // But always update the object, as the counter is updated frequently.
            self.webAuthn = webAuthn
        } else if let webAuthn = self.webAuthn {
            // And delete if necessary.
            switch webAuthn.algorithm {
            case .edDSA:
                try Keychain.shared.delete(id: id, service: .account(attribute: .webauthn))
            default:
                try Keychain.shared.deleteKey(id: id)
            }
            self.webAuthn = nil
        }
        return true
    }

    private  func updateNotes(with backupAccount: BackupUserAccount, context: LAContext?) throws -> Bool {
        let currentNotes = try notes()
        guard backupAccount.notes != currentNotes else {
            return false
        }
        if let newNotes = backupAccount.notes {
            if currentNotes != nil {
                try Keychain.shared.update(id: id, service: .account(attribute: .notes), secretData: newNotes.data, objectData: nil)
            } else {
                try Keychain.shared.save(id: id, service: .account(attribute: .notes), secretData: newNotes.data, objectData: nil)
            }
        } else {
            if currentNotes != nil {
                try Keychain.shared.delete(id: id, service: .account(attribute: .notes))
            }
        }
        return true
    }

    private func saveWebAuthn(webAuthn: WebAuthn, context: LAContext?) throws {
        let keyPair = try webAuthn.generateKeyPair(accountId: id, context: context)
        switch webAuthn.algorithm {
        case .edDSA:
            try Keychain.shared.save(id: id, service: .account(attribute: .webauthn), secretData: keyPair.privKey, objectData: keyPair.pubKey)
        case .ECDSA256:
            guard #available(iOS 13.0, *) else {
                throw WebAuthnError.notSupported
            }
            let privKey = try P256.Signing.PrivateKey(rawRepresentation: keyPair.privKey)
            try Keychain.shared.saveKey(id: id, key: privKey)
        case .ECDSA384:
            guard #available(iOS 13.0, *) else {
                throw WebAuthnError.notSupported
            }
            let privKey = try P384.Signing.PrivateKey(rawRepresentation: keyPair.privKey)
            try Keychain.shared.saveKey(id: id, key: privKey)
        case .ECDSA512:
            guard #available(iOS 13.0, *) else {
                throw WebAuthnError.notSupported
            }
            let privKey = try P521.Signing.PrivateKey(rawRepresentation: keyPair.privKey)
            try Keychain.shared.saveKey(id: id, key: privKey)
        }
    }

}

struct BackupUserAccount: BaseAccount, BackupObject {
    let id: String
    var username: String
    var sites: [Site]
    var passwordIndex: Int
    var passwordOffset: [Int]?
    var askToLogin: Bool?
    var askToChange: Bool?
    var enabled: Bool       // Deprecated
    var tokenURL: URL?
    var tokenSecret: Data?
    var version: Int
    var webAuthn: WebAuthn?
    var lastChange: Timestamp
    var notes: String?

    enum CodingKeys: CodingKey {
        case id
        case username
        case sites
        case passwordIndex
        case passwordOffset
        case askToLogin
        case askToChange
        case enabled
        case tokenURL
        case tokenSecret
        case version
        case webAuthn
        case lastChange
        case notes
    }

    init(account: UserAccount, tokenURL: URL?, tokenSecret: Data?, notes: String?) {
        self.id = account.id
        self.username = account.username
        self.sites = account.sites
        self.passwordIndex = account.passwordIndex
        self.passwordOffset = account.passwordOffset
        self.askToLogin = account.askToLogin
        self.askToChange = account.askToChange
        self.enabled = false
        self.tokenURL = tokenURL
        self.tokenSecret = tokenSecret
        self.version = account.version
        self.webAuthn = account.webAuthn
        self.lastChange = account.lastChange
        self.notes = notes
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try values.decode(String.self, forKey: .id)
        self.username = try values.decode(String.self, forKey: .username)
        self.sites = try values.decode([Site].self, forKey: .sites)
        self.passwordIndex = try values.decode(Int.self, forKey: .passwordIndex)
        self.passwordOffset = try values.decodeIfPresent([Int].self, forKey: .passwordOffset)
        self.askToLogin = try values.decodeIfPresent(Bool.self, forKey: .askToLogin)
        self.askToChange = try values.decodeIfPresent(Bool.self, forKey: .askToChange)
        self.enabled = false
        self.tokenURL = try values.decodeIfPresent(URL.self, forKey: .tokenURL)
        self.tokenSecret = try values.decodeIfPresent(Data.self, forKey: .tokenSecret)
        self.version = try values.decodeIfPresent(Int.self, forKey: .version) ?? 0
        self.webAuthn = try values.decodeIfPresent(WebAuthn.self, forKey: .webAuthn)
        self.lastChange = try values.decodeIfPresent(Timestamp.self, forKey: .lastChange) ?? 0
        self.notes = try values.decodeIfPresent(String.self, forKey: .notes)
    }

}
