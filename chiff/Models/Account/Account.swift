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

    func delete() -> Promise<Void>
    func update(secret: Data?, backup: Bool) throws
}

extension Account {

    /// Whether this account has an TOTP or HOTP code stored.
    var hasOtp: Bool {
        return Keychain.shared.has(id: id, service: .otp)
    }

    /// Retrieve the notes for this account.
    /// - Parameter context: Optionally, an authenticated `LAContext`.
    /// - Throws: May throw `KeychainError` or `CodingError.stringEncoding`.
    /// - Returns: The notes or nil if no notes are found.
    func notes(context: LAContext? = nil) throws -> String? {
        guard let data = try Keychain.shared.get(id: id, service: .notes, context: context) else {
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
            guard let urlData = try Keychain.shared.attributes(id: id, service: .otp, context: nil) else {
                return nil
            }
            let secret = try Keychain.shared.get(id: id, service: .otp, context: nil)
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
    ///   - migrateVersion: Set to true if this should attempt to migrate accounts to the next version.
    ///   - label: Optionally, a label to filter the the Keychain query.
    /// - Throws: May throw `KeychainError`.
    /// - Returns: A dictionary, where the id is the account ids and the value the `Account`.
    static func all(context: LAContext?, migrateVersion: Bool = false, label: String? = nil) throws -> [String: Self] {
        return try all(context: context, service: Self.keychainService, migrateVersion: migrateVersion, label: label)
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

    func deleteSync() throws {
        try Keychain.shared.delete(id: id, service: Self.keychainService)
        try? Keychain.shared.delete(id: id, service: .webauthn)
        try? Keychain.shared.delete(id: id, service: .notes)
        try? Keychain.shared.delete(id: id, service: .otp)
        try BrowserSession.all().forEach({ _ = $0.deleteAccount(accountId: id) })
        self.deleteFromToIdentityStore()
    }

    static func deleteAll() {
        Keychain.shared.deleteAll(service: Self.keychainService)
        Keychain.shared.deleteAll(service: .webauthn)
        Keychain.shared.deleteAll(service: .notes)
        Keychain.shared.deleteAll(service: .otp)
        if #available(iOS 12.0, *) {
            ASCredentialIdentityStore.shared.removeAllCredentialIdentities(nil)
        }
    }

    static func getAny(id: String, context: LAContext?) throws -> Account? {
        if let userAccount: UserAccount = try get(id: id, context: context, service: .account) {
            return userAccount
        } else if let sharedAccount: SharedAccount = try get(id: id, context: context, service: .sharedAccount) {
            return sharedAccount
        } else {
            return nil
        }
    }

    static func combinedSessionAccounts(context: LAContext? = nil) throws -> [String: SessionAccount] {
        return try allCombined(context: context).mapValues { SessionAccount(account: $0) }
    }

    static func allCombined(context: LAContext?, migrateVersion: Bool = false) throws -> [String: Account] {
        let userAccounts: [String: Account] = try all(context: context, service: .account, migrateVersion: migrateVersion) as [String: UserAccount]
        let sharedAccounts: [String: Account] = try all(context: context, service: .sharedAccount, migrateVersion: migrateVersion) as [String: SharedAccount]
        return userAccounts.merging(sharedAccounts, uniquingKeysWith: { (userAccount, _) -> Account in
            guard var account = userAccount as? UserAccount else {
                return userAccount
            }
            account.shadowing = true
            return account
        })
    }

    // MARK: - Private methods

    private static func get<T: Account>(id: String, context: LAContext?, service: KeychainService) throws -> T? {
        guard let accountData = try Keychain.shared.attributes(id: id, service: service, context: context) else {
            return nil
        }

        let decoder = PropertyListDecoder()

        return try decoder.decode(T.self, from: accountData)
    }

    private static func all<T: Account>(context: LAContext?, service: KeychainService, migrateVersion: Bool = false, label: String? = nil) throws -> [String: T] {
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
            if migrateVersion, var account = account as? UserAccount, account.version == 0 {
                account.updateVersion(context: context)
            }
            return (account.id, account)
        })
    }

}
