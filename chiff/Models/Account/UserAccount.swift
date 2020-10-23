/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import Foundation
import OneTimePassword
import LocalAuthentication
import AuthenticationServices
import CryptoKit
import PromiseKit

/*
 * An account belongs to the user and can have one Site.
 */
struct UserAccount: Account, Equatable {

    let id: String
    var username: String
    var sites: [Site]
    var passwordIndex: Int
    var lastPasswordUpdateTryIndex: Int
    var passwordOffset: [Int]?
    var askToLogin: Bool?
    var askToChange: Bool?
    var version: Int
    var webAuthn: WebAuthn?
    var timesUsed: Int
    var lastTimeUsed: Date?
    var lastChange: Timestamp
    var shadowing: Bool = false // This is set when loading accounts if there exists a team account with the same ID.

    static let keychainService: KeychainService = .account

    init(username: String,
         sites: [Site],
         password: String?,
         rpId: String?,
         algorithms: [WebAuthnAlgorithm]?,
         notes: String?,
         askToChange: Bool?,
         context: LAContext? = nil,
         offline: Bool = false) throws {
        id = "\(sites[0].id)_\(username)".hash

        self.sites = sites
        self.username = username
        self.version = 1
        self.askToChange = askToChange
        if let rpId = rpId, let algorithms = algorithms {
            self.webAuthn = try WebAuthn(id: rpId, algorithms: algorithms)
        }
        let keyPair = try webAuthn?.generateKeyPair(accountId: id, context: context)
        self.timesUsed = 0

        var generatedPassword = password
        if let password = password {
            let passwordGenerator = PasswordGenerator(username: username, siteId: sites[0].id, ppd: sites[0].ppd, passwordSeed: try Seed.getPasswordSeed(context: context))
            passwordOffset = try passwordGenerator.calculateOffset(index: 0, password: password)
            (generatedPassword, passwordIndex) = try passwordGenerator.generate(index: 0, offset: passwordOffset)
        } else if rpId != nil && algorithms != nil {
            // Initiate the account without a password
            self.passwordIndex = -1
            self.lastPasswordUpdateTryIndex = -1
        } else {
            let passwordGenerator = PasswordGenerator(username: username, siteId: sites[0].id, ppd: sites[0].ppd, passwordSeed: try Seed.getPasswordSeed(context: context))
            (generatedPassword, passwordIndex) = try passwordGenerator.generate(index: 0, offset: nil)
        }
        if let notes = notes, !notes.isEmpty {
            try Keychain.shared.save(id: id, service: .notes, secretData: notes.data, objectData: nil)
        }
        self.lastPasswordUpdateTryIndex = self.passwordIndex
        self.lastChange = Date.now
        try save(password: generatedPassword, keyPair: keyPair, offline: offline)
    }

    init(id: String, username: String, sites: [Site], passwordIndex: Int, lastPasswordTryIndex: Int,
         passwordOffset: [Int]?, askToLogin: Bool?, askToChange: Bool?, version: Int, webAuthn: WebAuthn?, notes: String?) {
        self.id = id
        self.username = username
        self.sites = sites
        self.passwordIndex = passwordIndex
        self.lastPasswordUpdateTryIndex = lastPasswordTryIndex
        self.passwordOffset = passwordOffset
        self.askToLogin = askToLogin
        self.askToChange = askToChange
        self.version = version
        self.webAuthn = webAuthn
        self.timesUsed = 0
        self.lastChange = Date.now
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
        self.lastChange = Date.now
        if self.hasOtp {
            try Keychain.shared.update(id: id, service: .otp, secretData: secret, objectData: tokenData)
        } else {
            try Keychain.shared.save(id: id, service: .otp, secretData: secret, objectData: tokenData)
        }
        _ = try backup()
    }

    mutating func updateNotes(notes: String) throws {
        self.lastChange = Date.now
        if Keychain.shared.has(id: id, service: .notes) {
            if notes.isEmpty {
                try Keychain.shared.delete(id: id, service: .notes)
            } else {
                try Keychain.shared.update(id: id, service: .notes, secretData: notes.data, objectData: nil)
            }
        } else if !notes.isEmpty {
            try Keychain.shared.save(id: id, service: .notes, secretData: notes.data, objectData: nil)
        }
        _ = try backup()
    }

    mutating func deleteOtp() throws {
        self.lastChange = Date.now
        try Keychain.shared.delete(id: id, service: .otp)
        _ = try backup()
        try BrowserSession.all().forEach({ try $0.updateSessionAccount(account: self) })
        saveToIdentityStore()
    }

    mutating func addSite(site: Site) throws {
        self.sites.append(site)
        self.lastChange = Date.now
        try update(secret: nil)
    }

    mutating func removeSite(forIndex index: Int) throws {
        self.sites.remove(at: index)
        self.lastChange = Date.now
        try update(secret: nil)
    }

    mutating func removeWebAuthn() throws {
        guard let webAuthn = webAuthn else {
            return
        }
        switch webAuthn.algorithm {
        case .edDSA:
            try Keychain.shared.delete(id: id, service: .webauthn)
        case .ECDSA:
            try Keychain.shared.deleteKey(id: id)
        }
        self.webAuthn = nil
        self.lastChange = Date.now
        try update(secret: nil)
    }

    mutating func updateSite(url: String, forIndex index: Int) throws {
        self.sites[index].url = url
        self.lastChange = Date.now
        try update(secret: nil)
    }

    func update(secret: Data?, backup: Bool = true) throws {
        let accountData = try PropertyListEncoder().encode(self as Self)
        try Keychain.shared.update(id: id, service: Self.keychainService, secretData: secret, objectData: accountData, context: nil)
        if backup {
            _ = try self.backup()
        }
        try BrowserSession.all().forEach({ try $0.updateSessionAccount(account: self as Self) })
        saveToIdentityStore()
    }

    mutating func update(username newUsername: String?, password newPassword: String?, siteName: String?, url: String?, askToLogin: Bool?, askToChange: Bool?, context: LAContext? = nil) throws {
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
        self.lastChange = Date.now
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
        self.lastChange = Date.now

        let accountData = try PropertyListEncoder().encode(self)
        try Keychain.shared.update(id: id, service: .account, secretData: newPassword.data, objectData: accountData)
        _ = try backup()
        NotificationCenter.default.postMain(Notification(name: .accountUpdated, object: self, userInfo: ["account": self]))
    }

    func delete() -> Promise<Void> {
        return firstly {
            Keychain.shared.delete(id: id, service: .account, reason: "Delete \(site.name)", authenticationType: .ifNeeded)
        }.map { _ in
            try self.webAuthn?.delete(accountId: self.id)
            try? Keychain.shared.delete(id: self.id, service: .notes)
            try? Keychain.shared.delete(id: self.id, service: .otp)
            try self.deleteBackup()
            try BrowserSession.all().forEach({ $0.deleteAccount(accountId: self.id) })
            self.deleteFromToIdentityStore()
            Logger.shared.analytics(.accountDeleted)
            Properties.accountCount -= 1
        }.log("Error deleting accounts")
    }

    func save(password: String?, keyPair: KeyPair?, offline: Bool = false) throws {
        let accountData = try PropertyListEncoder().encode(self)
        try Keychain.shared.save(id: id, service: Self.keychainService, secretData: password?.data, objectData: accountData)
        if let keyPair = keyPair {
            try webAuthn?.save(accountId: self.id, keyPair: keyPair)
        }
        if !offline {
            _ = try backup()
            try BrowserSession.all().forEach({ try $0.updateSessionAccount(account: self) })
        }
        saveToIdentityStore()
        Properties.accountCount += 1
    }

    // MARK: - WebAuthn functions

    mutating func webAuthnSign(challenge: String, rpId: String) throws -> (String, Int) {
        guard webAuthn != nil else {
            throw AccountError.noWebAuthn
        }
        let (signature, counter) = try webAuthn!.sign(accountId: self.id, challenge: challenge, rpId: rpId)
        self.lastChange = Date.now
        try update(secret: nil)
        return (signature, counter)
    }

    func webAuthnPubKey() throws -> String {
        guard let webAuthn = webAuthn else {
            throw AccountError.noWebAuthn
        }
        return try webAuthn.pubKey(accountId: self.id)
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
        case version
        case webAuthn
        case timesUsed
        case lastTimeUsed
        case lastChange
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
        self.version = try values.decodeIfPresent(Int.self, forKey: .version) ?? 0
        self.webAuthn = try values.decodeIfPresent(WebAuthn.self, forKey: .webAuthn)
        self.timesUsed = try values.decodeIfPresent(Int.self, forKey: .timesUsed) ?? 0
        self.lastTimeUsed = try values.decodeIfPresent(Date.self, forKey: .lastTimeUsed)
        self.lastChange = try values.decodeIfPresent(Timestamp.self, forKey: .lastChange) ?? 0
    }

}
