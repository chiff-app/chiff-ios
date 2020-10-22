//
//  UserAccount+Backupable.swift
//  keyn
//
//  Created by Bas Doorn on 17/03/2020.
//  Copyright © 2020 keyn. All rights reserved.
//

import Foundation

extension UserAccount: Backupable {

    enum BackupCodingKeys: CodingKey {
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

    func decode() throws {

    }

    func encode() throws {
        JSONDecoder().
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

}

struct BackupUserAccount: Codable {
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
