//
//  Account.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import Foundation
import OneTimePassword
import LocalAuthentication
import AuthenticationServices
import PromiseKit

enum AccountError: Error {
    case invalidURL
    case duplicateAccountId
    case accountsNotLoaded
    case notFound
    case missingContext
    case passwordGeneration
    case tokenRetrieval
    case wrongRpId
    case noWebAuthn
    case notTOTP
    case importError(failed: Int, total: Int)
}

protocol Account: BaseAccount {
    var askToLogin: Bool? { get set }
    var askToChange: Bool? { get set }
    var timesUsed: Int { get set }
    var lastTimeUsed: Date? { get set }

    static var keychainService: KeychainService { get }
    static var otpService: KeychainService { get }
    static var notesService: KeychainService { get }
    static var webAuthnService: KeychainService { get }

    /// Delete this account
    func delete() -> Promise<Void>

    /// Update the secret data
    /// - Parameters:
    ///   - secret: The secret data.
    ///   - backup: Whether a backup should be made.
    /// - Throws: Keychain or encoding errors.
    func update(secret: Data?, backup: Bool) throws
}

extension Account {

    /// Whether this account has an TOTP or HOTP code stored.
    var hasOtp: Bool {
        return Keychain.shared.has(id: id, service: Self.otpService)
    }

    /// Retrieve the notes for this account.
    /// - Parameter context: Optionally, an authenticated `LAContext`.
    /// - Throws: May throw `KeychainError` or `CodingError.stringEncoding`.
    /// - Returns: The notes or nil if no notes are found.
    func notes(context: LAContext? = nil) throws -> String? {
        guard let data = try Keychain.shared.get(id: id, service: Self.notesService, context: context) else {
            return nil
        }
        guard let notes = String(data: data, encoding: .utf8) else {
            throw CodingError.stringEncoding
        }
        return notes
    }

    /// Retrieve the password for this account.
    /// - Parameter context: Optionally, an authenticated `LAContext`.
    /// - Throws: May throw `KeychainError` or `CodingError.stringEncoding`.
    /// - Returns: The password or nil if no password is found.
    func password(context: LAContext? = nil) throws -> String? {
        do {
            guard let data = try Keychain.shared.get(id: id, service: Self.keychainService, context: context) else {
                return nil
            }

            guard let password = String(data: data, encoding: .utf8) else {
                throw CodingError.stringEncoding
            }

            return password
        } catch {
            Logger.shared.error("Could not retrieve password from account", error: error, userInfo: nil)
            throw error
        }
    }

    /// Retrieve the password using the Keychain's async method.
    /// This method will prompt the user for authentication if the `LAContext` is not valid.
    /// - Parameters:
    ///   - reason: The reason that will be presented to the user in case authentication is needed.
    ///   - context: Optionally, an `LAContext` object
    ///   - type: The `AuthenticationType`, which determines if prompting for authentication is forced.
    /// - Returns: The password or nil if no password is found.
    func password(reason: String, context: LAContext? = nil, type: AuthenticationType) -> Promise<String?> {
        return firstly {
            Keychain.shared.get(id: id, service: Self.keychainService, reason: reason, with: context, authenticationType: type)
        }.map { data in
            guard let data = data else {
                return nil
            }
            guard let password = String(data: data, encoding: .utf8) else {
                throw CodingError.stringEncoding
            }
            return password
        }
    }

    /// Retrieve the OTP-token.
    /// - Throws: May throw `KeychainError` or `CodingError.unexpectedData`.
    /// - Returns: The `Token` or nil if no token is found.
    func oneTimePasswordToken() throws -> Token? {
        do {
            guard let urlData = try Keychain.shared.attributes(id: id, service: Self.otpService, context: nil) else {
                return nil
            }
            let secret = try Keychain.shared.get(id: id, service: Self.otpService, context: nil)
            guard let urlString = String(data: urlData, encoding: .utf8),
                let url = URL(string: urlString) else {
                    throw CodingError.unexpectedData
            }

            return Token(url: url, secret: secret)
        } catch {
            throw AccountError.tokenRetrieval
        }
    }

    /// Call this to update the usage counter, which is used to sort accounts by *last use* or *most used* in the account overview.
    mutating func increaseUse() {
        do {
            lastTimeUsed = Date()
            timesUsed += 1
            try update(secret: nil, backup: false)
        } catch {
            Logger.shared.error(error.localizedDescription)
        }
    }

    // MARK: - Static functions

    /// Get all accounts.
    /// - Parameters:
    ///   - context: Optionally, an `LAContext` object.
    ///   - label: Optionally, a label to filter the the Keychain query.
    /// - Throws: May throw `KeychainError`.
    /// - Returns: A dictionary, where the id is the account ids and the value the `Account`.
    static func all(context: LAContext?, label: String? = nil) throws -> [String: Self] {
        return try all(context: context, service: Self.keychainService, label: label)
    }

    /// Get a single account.
    /// - Parameters:
    ///   - id: The account id.
    ///   - context: Optionally, an `LAContext` object.
    /// - Throws: May throw `KeychainError`.
    /// - Returns: The account or nil of no account with this id is found.
    static func get(id: String, context: LAContext?) throws -> Self? {
        return try get(id: id, context: context, service: Self.keychainService)
    }

    /// Delete data from Keychain. This method deleted the account, notes and OTP if they exist. In addition, it deletes the accounts from the session and
    /// the identity store.
    /// - Important: It does **not** delete the backup, nor WebAuthn data.
    func deleteFromKeychain() -> Promise<Void> {
        do {
            try Keychain.shared.delete(id: id, service: Self.keychainService)
            try? Keychain.shared.delete(id: id, service: Self.notesService)
            try? Keychain.shared.delete(id: id, service: Self.otpService)
            self.deleteFromToIdentityStore()
            return when(fulfilled: try BrowserSession.all().map({ $0.deleteAccount(accountId: self.id) }))
        } catch {
            return Promise(error: error)
        }
    }

    /// Delete all accounts and related to from the Keychain and identity store.
    static func deleteAll() {
        Keychain.shared.deleteAll(service: Self.keychainService)
        Keychain.shared.deleteAll(service: Self.webAuthnService)
        Keychain.shared.deleteAllKeys() // This deletes ECDSA keys for WebAuthn
        Keychain.shared.deleteAll(service: Self.notesService)
        Keychain.shared.deleteAll(service: Self.otpService)
        if #available(iOS 12.0, *) {
            ASCredentialIdentityStore.shared.removeAllCredentialIdentities(nil)
        }
    }

    /// Get an `Account`, without caring whether it is a `UserAccount` or `SharedAccount`.
    /// - Note: `UserAccount` prevails over `SharedAccount`.
    /// - ToDo: This method is a bit weird, since it is called on `UserAccount` or `SharedAccount`, but can return both.
    /// The most logical way would be to call `Account.get()` to get either a `SharedAccount` or
    /// `UserAccount`, and `UserAccount.get()` / `SharedAccount.get()` to respectively get a `UserAccount` or `SharedAccount`,
    /// but we cannot call a method directly on the protocol.
    /// - Parameters:
    ///   - id: The account identifier
    ///   - context: Optionally, an authenticated `LAContext` object.
    /// - Throws: May throw Keychain errors or decoding errors.
    /// - Returns: The account, if found.
    static func getAny(id: String, context: LAContext?) throws -> Account? {
        if let userAccount: UserAccount = try get(id: id, context: context, service: .account()) {
            return userAccount
        } else if let sharedAccount: SharedAccount = try get(id: id, context: context, service: .sharedAccount()) {
            return sharedAccount
        } else {
            return nil
        }
    }

    /// Get the `SessionAccount`, which can be used to inform the session client which accounts are available.
    /// - Parameter context: Optionally, an authenticated `LAContext` object.
    /// - Throws: May throw Keychain errors or decoding errors.May throw Keychain errors or decoding errors.
    /// - Returns: A dictionary of `SessionAccount`s, where the keys are the ids.
    static func combinedSessionAccounts(context: LAContext? = nil) throws -> [String: SessionAccount] {
        return try allCombined(context: context).mapValues { SessionAccount(account: $0) }
    }

    /// Get a dictionary of accounts, both `UserAccount` and `SharedAccount`.
    /// - ToDo: This method is a bit weird, since it is called on `UserAccount` or `SharedAccount`, but returns both.
    /// The most logical way would be to call `Account.all()` to get a combination of `SharedAccount`s and `UserAccount`s,
    /// and `UserAccount.all()` / `SharedAccount.all()` to respectively get a dictionary of `UserAccount`s or `SharedAccount`s,
    /// but we cannot call a method directly on the protocol.
    /// - Parameters:
    ///   - context: Optionally, an authenticated `LAContext` object.
    ///   - migrateVersion: If this is true, we try to check if there are outdated accounts that should be updated.
    /// - Throws: May throw Keychain errors or decoding errors.May throw Keychain errors or decoding errors.
    /// - Note: If a `UserAccount` and a `SharedAccount` exists with the same ID, they `UserAccount` is returned, but with the `shadowing` attribute set.
    /// - Returns: A dictionary of `Account`s, where the keys are the ids.
    static func allCombined(context: LAContext?, migrateVersion: Bool = false) throws -> [String: Account] {
        let sharedAccounts: [String: Account] = try all(context: context, service: .sharedAccount()) as [String: SharedAccount]
        let userAccounts: [String: Account] = try all(context: context, service: .account()).mapValues({ (account: UserAccount) -> Account in
            var account = account
            if migrateVersion, account.version <= 1 {
                account.updateVersion(context: context)
            }
            if sharedAccounts[account.id] != nil {
                account.shadowing = true
            }
            return account as Account
        })
        return userAccounts.merging(sharedAccounts) { (userAccount, _) in userAccount }
    }

    // MARK: - Private methods

    private static func get<T: Account>(id: String, context: LAContext?, service: KeychainService) throws -> T? {
        guard let accountData = try Keychain.shared.attributes(id: id, service: service, context: context) else {
            return nil
        }

        let decoder = PropertyListDecoder()

        return try decoder.decode(T.self, from: accountData)
    }

    private static func all<T: Account>(context: LAContext?, service: KeychainService, label: String? = nil) throws -> [String: T] {
        guard let dataArray = try Keychain.shared.all(service: service, context: context, label: label) else {
            return [:]
        }
        Properties.accountCount = dataArray.count
        let decoder = PropertyListDecoder()

        return Dictionary(uniqueKeysWithValues: try dataArray.map { (dict) in
            guard let accountData = dict[kSecAttrGeneric as String] as? Data else {
                throw CodingError.unexpectedData
            }
            let account = try decoder.decode(T.self, from: accountData)
            return (account.id, account)
        })
    }

}
