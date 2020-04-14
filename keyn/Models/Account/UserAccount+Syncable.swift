//
//  UserAccount+Restorable.swift
//  keyn
//
//  Created by Bas Doorn on 17/03/2020.
//  Copyright © 2020 keyn. All rights reserved.
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

    static func all(context: LAContext?) throws -> [String : UserAccount] {
        return try all(context: context, sync: false, label: nil)
    }

    static func create(backupObject: BackupUserAccount, context: LAContext?) throws {
        let _ = try UserAccount(backupObject: backupObject, context: context)
    }

    static func notifyObservers() {
        NotificationCenter.default.postMain(name: .accountsLoaded, object: nil)
    }

    // MARK: - Init

    init(backupObject: BackupUserAccount, context: LAContext?) throws {
        id = backupObject.id
        username = backupObject.username
        sites = backupObject.sites
        passwordIndex = backupObject.passwordIndex
        lastPasswordUpdateTryIndex = backupObject.lastPasswordUpdateTryIndex
        passwordOffset = backupObject.passwordOffset
        askToLogin = backupObject.askToLogin
        askToChange = backupObject.askToChange
        enabled = backupObject.enabled
        version = backupObject.version
        webAuthn = backupObject.webAuthn
        timesUsed = 0
        lastTimeUsed = nil
        lastChange = backupObject.lastChange

        var password: String? = nil
        if passwordIndex >= 0 {
            let passwordGenerator = try PasswordGenerator(username: username, siteId: site.id, ppd: site.ppd, passwordSeed: Seed.getPasswordSeed(context: context))
            (password, _) = try passwordGenerator.generate(index: passwordIndex, offset: passwordOffset)
        }

        // Remove token and save seperately in Keychain
        if let tokenSecret = backupObject.tokenSecret, let tokenURL = backupObject.tokenURL {
            let tokenData = tokenURL.absoluteString.data
            try Keychain.shared.save(id: id, service: .otp, secretData: tokenSecret, objectData: tokenData)
        }

        // Webauthn
        if let webAuthn = webAuthn {
            let keyPair = try webAuthn.generateKeyPair(accountId: id, context: context)
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

        if let notes = backupObject.notes, !notes.isEmpty {
            try Keychain.shared.save(id: id, service: .notes, secretData: notes.data, objectData: nil)
        }

        let data = try PropertyListEncoder().encode(self)
        try Keychain.shared.save(id: id, service: Self.keychainService, secretData: password?.data, objectData: data)
        saveToIdentityStore()
    }

    func backup() throws -> Promise<Void> {
        var tokenURL: URL? = nil
        var tokenSecret: Data? = nil
        if let token = try oneTimePasswordToken() {
            tokenURL = try token.toURL()
            tokenSecret = token.generator.secret
        }
        return firstly {
            sendData(item: BackupUserAccount(account: self, tokenURL: tokenURL, tokenSecret: tokenSecret, notes: try notes()))
        }.map { _ in
            try Keychain.shared.setSynced(value: true, id: self.id, service: Self.keychainService)
        }.recover { error in
            try Keychain.shared.setSynced(value: false, id: self.id, service: Self.keychainService)
            throw error
        }.log("Error setting account sync info")
    }

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
        if backupAccount.enabled != enabled {
            self.enabled = backupAccount.enabled
            changed = true
        }
        if backupAccount.version != version {
            self.version = backupAccount.version
            changed = true
        }
        return (changed, updatePassword)
    }

    private mutating func updateToken(with backupAccount: BackupUserAccount, context: LAContext?) throws -> Bool {
        var tokenURL: URL? = nil
        var tokenSecret: Data? = nil
        if let token = try oneTimePasswordToken() {
            tokenURL = try token.toURL()
            tokenSecret = token.generator.secret
        }
        guard tokenSecret != backupAccount.tokenSecret || tokenURL != backupAccount.tokenURL else {
            return false
        }
        if let newTokenSecret = backupAccount.tokenSecret, let newTokenURLData = backupAccount.tokenURL?.absoluteString.data {
            if tokenSecret != nil {
                try Keychain.shared.update(id: id, service: .otp, secretData: newTokenSecret, objectData: newTokenURLData)
            } else {
                try Keychain.shared.save(id: id, service: .otp, secretData: newTokenSecret, objectData: newTokenURLData)
            }
        } else if tokenSecret != nil {
            try Keychain.shared.delete(id: id, service: .otp)
        }
        return true
    }

    private mutating func updateWebAuthn(with backupAccount: BackupUserAccount, context: LAContext?) throws -> Bool {
        guard backupAccount.webAuthn != webAuthn else {
            return false
        }
        if let webAuthn = backupAccount.webAuthn {
            let keyPair = try webAuthn.generateKeyPair(accountId: id, context: context)
            switch webAuthn.algorithm {
            case .EdDSA:
                if self.webAuthn != nil {
                    try Keychain.shared.update(id: id, service: .webauthn, secretData: keyPair.privKey, objectData: keyPair.pubKey)
                } else {
                    try Keychain.shared.save(id: id, service: .webauthn, secretData: keyPair.privKey, objectData: keyPair.pubKey)
                }
            case .ECDSA:
                guard #available(iOS 13.0, *) else {
                    throw WebAuthnError.notSupported
                }
                let privKey = try P256.Signing.PrivateKey(rawRepresentation: keyPair.privKey)
                // TODO: Add key update function to keychain
                if self.webAuthn != nil {
                    try Keychain.shared.deleteKey(id: id)
                }
                try Keychain.shared.saveKey(id: id, key: privKey)
            }
            self.webAuthn = webAuthn
        } else if let webAuthn = self.webAuthn {
            switch webAuthn.algorithm {
            case .EdDSA:
                try Keychain.shared.delete(id: id, service: .webauthn)
            case .ECDSA:
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
            if Keychain.shared.has(id: id, service: .notes) {
                if newNotes.isEmpty {
                    try Keychain.shared.delete(id: id, service: .notes)
                } else {
                    try Keychain.shared.update(id: id, service: .notes, secretData: newNotes.data, objectData: nil)
                }
            } else if !newNotes.isEmpty {
                try Keychain.shared.save(id: id, service: .notes, secretData: newNotes.data, objectData: nil)
            }
        }
        return true
    }
    
}

struct BackupUserAccount: BaseAccount, BackupObject {
    let id: String
    var username: String
    var sites: [Site]
    var passwordIndex: Int
    var lastPasswordUpdateTryIndex: Int
    var passwordOffset: [Int]?
    var askToLogin: Bool?
    var askToChange: Bool?
    var enabled: Bool
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
        case lastPasswordUpdateTryIndex
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
        self.lastPasswordUpdateTryIndex = account.lastPasswordUpdateTryIndex
        self.passwordOffset = account.passwordOffset
        self.askToLogin = account.askToLogin
        self.askToChange = account.askToChange
        self.enabled = account.enabled
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
        self.lastPasswordUpdateTryIndex = try values.decode(Int.self, forKey: .lastPasswordUpdateTryIndex)
        self.passwordOffset = try values.decodeIfPresent([Int].self, forKey: .passwordOffset)
        self.askToLogin = try values.decodeIfPresent(Bool.self, forKey: .askToLogin)
        self.askToChange = try values.decodeIfPresent(Bool.self, forKey: .askToChange)
        self.enabled = try values.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
        self.tokenURL = try values.decodeIfPresent(URL.self, forKey: .tokenURL)
        self.tokenSecret = try values.decodeIfPresent(Data.self, forKey: .tokenSecret)
        self.version = try values.decodeIfPresent(Int.self, forKey: .version) ?? 0
        self.webAuthn = try values.decodeIfPresent(WebAuthn.self, forKey: .webAuthn)
        self.lastChange = try values.decodeIfPresent(Timestamp.self, forKey: .lastChange) ?? 0
        self.notes = try values.decodeIfPresent(String.self, forKey: .notes)
    }

}
