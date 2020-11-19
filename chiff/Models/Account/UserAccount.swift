//
//  UserAccount.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

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

    static let keychainService: KeychainService = .account()
    static let otpService: KeychainService = .account(attribute: .otp)
    static let notesService: KeychainService = .account(attribute: .notes)
    static let webAuthnService: KeychainService = .account(attribute: .webauthn)

    /// Create a `UserAccount`. This generates passwords or offset and saves the account to the Keychain as well.
    /// - Parameters:
    ///   - username: The username
    ///   - sites: An array of websites, where the first in the array will be used as the primary website.
    ///   - password: Optionally, a password. If no password is provided, it will be generated. If it is provided, an offset will be calculated and saved.
    ///   - rpId: A WebAuthn relying party ID
    ///   - algorithms: A set of algorithms used for WebAuthn.
    ///   - notes: Notes to save with the account.
    ///   - askToChange: Whether clients should ask to change the password.
    ///   - context: Optionally, an authenticated `LAContext` object.
    ///   - offline: If this is true, no remote calls should be made (creating the backup and the session accounts).
    /// - Throws: Keychain or password generation errors.
    init(username: String,
         sites: [Site],
         password: String?,
         rpId: String?,
         algorithms: [WebAuthnAlgorithm]?,
         notes: String?,
         askToChange: Bool?,
         context: LAContext? = nil,
         offline: Bool = false) throws {
        guard let id = "\(sites[0].id)_\(username)".hash else {
            throw CryptoError.hashing
        }
        self.id = id
        self.sites = sites
        self.username = username
        self.version = 2
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
            try Keychain.shared.save(id: id, service: Self.notesService, secretData: notes.data, objectData: nil)
        }
        self.lastPasswordUpdateTryIndex = self.passwordIndex
        self.lastChange = Date.now
        try save(password: generatedPassword, keyPair: keyPair, offline: offline)
    }

    /// Create a `UserAccount`, without saving to the Keychain or generating passwords.
    /// - Parameters:
    ///   - id: The account id.
    ///   - username: The username.
    ///   - sites: An array of websites, where the first in the array will be used as the primary website
    ///   - passwordIndex: The password index to start generating passwords.
    ///   - lastPasswordTryIndex: The last index that has been used to generate a password.
    ///   - passwordOffset: The offset to generate a user-chosen password.
    ///   - askToLogin: Whether the client should ask to log in.
    ///   - askToChange: Whether the client should ask to change the password.
    ///   - version: The account version.
    ///   - webAuthn: A `WebAuthn` object.
    ///   - notes: Notes for this account.
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

    /// Generate a new password. Uses the PPD if present.
    /// - Note: Does not save the password yet. Only updated the `lastPasswordUpdateTryIndex`.
    /// - Parameter context: Optionally, an authenticated `LAContext` object.
    /// - Throws: Keychain or encoding errors.
    /// - Returns: The new password.
    mutating func nextPassword(context: LAContext? = nil) throws -> String {
        let offset: [Int]? = nil // Will it be possible to change to custom password?
        let passwordGenerator = try PasswordGenerator(username: username, siteId: site.id, ppd: site.ppd, passwordSeed: Seed.getPasswordSeed(context: context))
        let (newPassword, index) = try passwordGenerator.generate(index: lastPasswordUpdateTryIndex + 1, offset: offset)
        self.lastPasswordUpdateTryIndex = index
        let accountData = try PropertyListEncoder().encode(self)
        try Keychain.shared.update(id: id, service: Self.keychainService, secretData: nil, objectData: accountData)
        return newPassword
    }

    /// After saving a new (generated) password in the browser we place a message
    /// on the queue stating that it succeeded. We call this function to
    /// confirm the new password and store it in the account.
    /// - Parameter context: Optionally, an authenticated `LAContext` object.
    /// - Throws: Keychain, encoding or password generation errors.
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
        try Keychain.shared.update(id: id, service: Self.keychainService, secretData: newPassword.data, objectData: accountData)
        _ = try backup()
        NotificationCenter.default.postMain(Notification(name: .accountUpdated, object: self, userInfo: ["account": self]))
    }

    /// Set an OTP token for this account.
    /// - Parameter token: The `Token`.
    /// - Throws: Keychain or decoding errors.
    mutating func setOtp(token: Token) throws {
        let secret = token.generator.secret
        let tokenData = try token.toURL().absoluteString.data
        self.lastChange = Date.now
        if self.hasOtp {
            try Keychain.shared.update(id: id, service: Self.otpService, secretData: secret, objectData: tokenData)
        } else {
            try Keychain.shared.save(id: id, service: Self.otpService, secretData: secret, objectData: tokenData)
        }
        _ = try backup()
    }

    /// Update the notes for this account.
    /// - Parameter notes: The notes
    /// - Throws: Keychain or decoding errors.
    mutating func updateNotes(notes: String) throws {
        self.lastChange = Date.now
        if Keychain.shared.has(id: id, service: Self.notesService) {
            if notes.isEmpty {
                try Keychain.shared.delete(id: id, service: Self.notesService)
            } else {
                try Keychain.shared.update(id: id, service: Self.notesService, secretData: notes.data, objectData: nil)
            }
        } else if !notes.isEmpty {
            try Keychain.shared.save(id: id, service: Self.notesService, secretData: notes.data, objectData: nil)
        }
        _ = try backup()
    }

    /// Delete the OTP token from this account.
    /// - Throws: Keychain or decoding errors.
    mutating func deleteOtp() throws {
        self.lastChange = Date.now
        try Keychain.shared.delete(id: id, service: Self.otpService)
        _ = try backup()
        try BrowserSession.all().forEach({ _ = try $0.updateSessionAccount(account: self) })
        saveToIdentityStore()
    }

    /// Add a website to the array of sites.
    /// - Parameter site: The site to add.
    /// - Throws: Keychain errors.
    mutating func addSite(site: Site) throws {
        self.sites.append(site)
        self.lastChange = Date.now
        try update(secret: nil)
    }

    /// Remove a website from the array of sites.
    /// - Parameter index: The index of the website to remove.
    /// - Throws: Keychain errors.
    mutating func removeSite(forIndex index: Int) throws {
        self.sites.remove(at: index)
        self.lastChange = Date.now
        try update(secret: nil)
    }

    /// Remove the `WebAuthn` object from this account, if it exists.
    /// - Throws: Keychain errors
    mutating func removeWebAuthn() throws {
        guard let webAuthn = webAuthn else {
            return
        }
        switch webAuthn.algorithm {
        case .edDSA:
            try Keychain.shared.delete(id: id, service: Self.webAuthnService)
        case .ECDSA:
            try Keychain.shared.deleteKey(id: id)
        }
        self.webAuthn = nil
        self.lastChange = Date.now
        try update(secret: nil)
    }

    /// Update the URL of website in the array of sites.
    /// - Parameters:
    ///   - url: The new URL.
    ///   - index: The index of the site that should be updated.
    /// - Throws: Keychain errors.
    mutating func updateSite(url: String, forIndex index: Int) throws {
        self.sites[index].url = url
        self.lastChange = Date.now
        try update(secret: nil)
    }

    // Documentation in protocol
    func update(secret: Data?, backup: Bool = true) throws {
        let accountData = try PropertyListEncoder().encode(self as Self)
        try Keychain.shared.update(id: id, service: Self.keychainService, secretData: secret, objectData: accountData, context: nil)
        if backup {
            _ = try self.backup()
        }
        try BrowserSession.all().forEach({ _ = try $0.updateSessionAccount(account: self as Self) })
        saveToIdentityStore()
    }

    /// Update attributes of this account. Each element is optional and only will be updated if it is provided.
    /// - Parameters:
    ///   - newUsername: The new username.
    ///   - newPassword: The new password.
    ///   - siteName: The new site name for the main site.
    ///   - url: The new URL for the main site.
    ///   - askToLogin: Whether the client should ask to log in.
    ///   - askToChange: Whether the client should ask to change.
    ///   - context: Optionally, an authenticated `LAContext` object.
    /// - Throws: Keychain and password generation errors.
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

    func delete() -> Promise<Void> {
        do {
            try self.webAuthn?.delete(accountId: self.id)
            return firstly {
                when(fulfilled: [self.deleteBackup(), self.deleteFromKeychain()])
            }.done {
                Logger.shared.analytics(.accountDeleted)
                Properties.accountCount -= 1
            }
        } catch {
            return Promise(error: error)
        }
    }

    // MARK: - WebAuthn functions

    /// Sign a WebAuthn challenge.
    /// - Parameters:
    ///   - challenge: The challenge that should be signed.
    ///   - rpId: The relying party id.
    /// - Throws: Keychain or cryptography errors.
    /// - Returns: A tuple of the signature and counter.
    mutating func webAuthnSign(challenge: String, rpId: String) throws -> (String, Int) {
        guard webAuthn != nil else {
            throw AccountError.noWebAuthn
        }
        let (signature, counter) = try webAuthn!.sign(accountId: self.id, challenge: challenge, rpId: rpId)
        self.lastChange = Date.now
        try update(secret: nil)
        return (signature, counter)
    }

    /// Return the WebAuthn public key.
    /// - Throws: Keychain or cryptography errors.
    /// - Returns: The public key, base64 encoded.
    func webAuthnPubKey() throws -> String {
        guard let webAuthn = webAuthn else {
            throw AccountError.noWebAuthn
        }
        return try webAuthn.pubKey(accountId: self.id)
    }

    // MARK: - Private functions

    private func save(password: String?, keyPair: KeyPair?, offline: Bool = false) throws {
        let accountData = try PropertyListEncoder().encode(self)
        try Keychain.shared.save(id: id, service: Self.keychainService, secretData: password?.data, objectData: accountData)
        if let keyPair = keyPair {
            try webAuthn?.save(accountId: self.id, keyPair: keyPair)
        }
        if !offline {
            _ = try backup()
            try BrowserSession.all().forEach({ _ = try $0.updateSessionAccount(account: self) })
        }
        saveToIdentityStore()
        Properties.accountCount += 1
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
