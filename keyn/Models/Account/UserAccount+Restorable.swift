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

extension UserAccount: Restorable {

    static var backupEndpoint: BackupEndpoint {
        return .accounts
    }

    static func restore(data: Data, context: LAContext?) throws -> UserAccount {
        return try UserAccount(data: data, context: context)
    }

    static func sync(context: LAContext?) -> Promise<Void> {
        return firstly {
            API.shared.signedRequest(method: .get, message: nil, path: "users/\(try BackupManager.publicKey())/\(backupEndpoint.rawValue)", privKey: try BackupManager.privateKey(), body: nil)
        }.map { result in
            var changed = false
            var currentAccounts = try all(context: context, sync: false, label: nil)
            let seed = try Seed.getPasswordSeed(context: context)
            for (id, data) in result {
                if let base64Data = data as? String {
                    do {
                        let ciphertext = try Crypto.shared.convertFromBase64(from: base64Data)
                        guard let key = try Keychain.shared.get(id: KeyIdentifier.encryption.identifier(for: .backup), service: .backup) else {
                            throw KeychainError.notFound
                        }
                        let data = try Crypto.shared.decryptSymmetric(ciphertext, secretKey: key)
                        if var account = try get(id: id, context: context) {
                            currentAccounts.removeValue(forKey: account.id)
                            if try account.sync(data: data, seed: seed, context: context) {
                                changed = true
                            }
                        } else {
                            // Item doesn't exist, create.
                            let _ = try restore(data: data, context: context)
                            changed = true
                        }
                    } catch {
                        Logger.shared.error("Could not restore data.", error: error)
                    }
                }
            }
            for account in currentAccounts.values {
                #warning("Check how to safely delete here in the background")
                try account.deleteSync()
                changed = true
            }
            if changed {
                Properties.accountCount = result.count
                NotificationCenter.default.postMain(name: .accountsLoaded, object: nil)
            }
        }.asVoid().log("Error syncing accounts")
    }

    init(data: Data, context: LAContext?) throws {
        let backupAccount = try JSONDecoder().decode(BackupUserAccount.self, from: data)
        id = backupAccount.id
        username = backupAccount.username
        sites = backupAccount.sites
        passwordIndex = backupAccount.passwordIndex
        lastPasswordUpdateTryIndex = backupAccount.lastPasswordUpdateTryIndex
        passwordOffset = backupAccount.passwordOffset
        askToLogin = backupAccount.askToLogin
        askToChange = backupAccount.askToChange
        enabled = backupAccount.enabled
        version = backupAccount.version
        webAuthn = backupAccount.webAuthn
        timesUsed = 0
        lastTimeUsed = nil

        var password: String? = nil
        if passwordIndex >= 0 {
            let passwordGenerator = try PasswordGenerator(username: username, siteId: site.id, ppd: site.ppd, passwordSeed: Seed.getPasswordSeed(context: context))
            (password, _) = try passwordGenerator.generate(index: passwordIndex, offset: passwordOffset)
        }

        // Remove token and save seperately in Keychain
        if let tokenSecret = backupAccount.tokenSecret, let tokenURL = backupAccount.tokenURL {
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
        let account = BackupUserAccount(account: self, tokenURL: tokenURL, tokenSecret: tokenSecret)
        let data = try JSONEncoder().encode(account)
        return firstly {
            backup(data: data)
        }.map { _ in
            try Keychain.shared.setSynced(value: true, id: self.id, service: Self.keychainService)
        }.recover { error in
            try Keychain.shared.setSynced(value: false, id: self.id, service: Self.keychainService)
            throw error
        }.log("Error setting account sync info")
    }

    mutating func sync(data: Data, seed: Data, context: LAContext? = nil) throws -> Bool {
        let backupAccount = try JSONDecoder().decode(BackupUserAccount.self, from: data)
        // Attributes
        var (changed, updatePassword) = syncAttributes(backupAccount: backupAccount)

        // Password
        var password: String?
        var newIndex: Int!
        if updatePassword {
            let passwordGenerator = PasswordGenerator(username: self.username, siteId: site.id, ppd: site.ppd, passwordSeed: seed)
            (password, newIndex) = try passwordGenerator.generate(index: backupAccount.passwordIndex, offset: self.passwordOffset)
            guard self.passwordIndex == newIndex else {
                throw AccountError.passwordGeneration
            }
        }

        // OTP
        if try syncToken(backupAccount: backupAccount, context: context) {
            changed = true
        }

        // Webauthn
        if try syncWebAuthn(backupAccount: backupAccount, context: context) {
            changed = true
        }
        if changed {
            try update(secret: password?.data, backup: false)
        }
        return changed
    }

    private mutating func syncAttributes(backupAccount: BackupUserAccount) -> (Bool, Bool) {
        var updatePassword = false
        var changed = false
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

    private mutating func syncToken(backupAccount: BackupUserAccount, context: LAContext?) throws -> Bool {
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

    private mutating func syncWebAuthn(backupAccount: BackupUserAccount, context: LAContext?) throws -> Bool {
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

}

fileprivate struct BackupUserAccount: BaseAccount {
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
    }

    init(account: UserAccount, tokenURL: URL?, tokenSecret: Data?) {
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
    }

}
