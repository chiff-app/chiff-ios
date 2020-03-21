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

    static func restore(data: Data, id: String, context: LAContext?) throws -> UserAccount {
        let decoder = JSONDecoder()
        let backupAccount = try decoder.decode(BackupUserAccount.self, from: data)
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

        try Keychain.shared.save(id: account.id, service: Self.keychainService, secretData: password?.data, objectData: data)
        account.saveToIdentityStore()
        return account
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




