/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import Foundation
import OneTimePassword
import LocalAuthentication
import AuthenticationServices
import PromiseKit

enum AccountError: KeynError {
    case duplicateAccountId
    case accountsNotLoaded
    case notFound
    case missingContext
    case passwordGeneration
    case tokenRetrieval
    case wrongRpId
    case noWebAuthn
}

protocol Account: BaseAccount {
    var askToLogin: Bool? { get set }
    var askToChange: Bool? { get set }
    var synced: Bool { get }
    var enabled: Bool { get }

    static var keychainService: KeychainService { get }

    func backup() throws
    func delete() -> Promise<Void>
}

extension Account {

    var hasOtp: Bool {
        return Keychain.shared.has(id: id, service: .otp)
    }

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

    func oneTimePasswordToken() throws -> Token? {
        do {
            guard let urlDataDict = try Keychain.shared.attributes(id: id, service: .otp, context: nil) else {
                return nil
            }
            let secret = try Keychain.shared.get(id: id, service: .otp, context: nil)
            guard let urlData = urlDataDict[kSecAttrGeneric as String] as? Data, let urlString = String(data: urlData, encoding: .utf8),
                let url = URL(string: urlString) else {
                    throw CodingError.unexpectedData
            }

            return Token(url: url, secret: secret)
        } catch {
            throw AccountError.tokenRetrieval
        }
    }

    func update(secret: Data?) throws {
        let accountData = try PropertyListEncoder().encode(self as Self)
        try Keychain.shared.update(id: id, service: Self.keychainService, secretData: secret, objectData: accountData, context: nil)
        try backup()
        try BrowserSession.all().forEach({ try $0.updateAccountList(account: self as Self) })
        saveToIdentityStore()
    }

    // MARK: - Static functions

    static func all(context: LAContext?, sync: Bool = false, label: String? = nil) throws -> [String: Self] {
        guard let dataArray = try Keychain.shared.all(service: Self.keychainService, context: context, label: label) else {
            return [:]
        }
        Properties.accountCount = dataArray.count
        let decoder = PropertyListDecoder()

        return Dictionary(uniqueKeysWithValues: try dataArray.map { (dict) in
            guard let accountData = dict[kSecAttrGeneric as String] as? Data else {
                throw CodingError.unexpectedData
            }
            let account = try decoder.decode(Self.self, from: accountData)
            if sync {
                if var account = account as? UserAccount, account.version == 0 {
                    account.updateVersion(context: context)
                } else if !account.synced {
                    try? account.backup()
                }
            }
            return (account.id, account)
            })
    }

    static func get(accountID: String, context: LAContext?) throws -> Self? {
        guard let dict = try Keychain.shared.attributes(id: accountID, service: Self.keychainService, context: context) else {
            return nil
        }

        let decoder = PropertyListDecoder()

        guard let accountData = dict[kSecAttrGeneric as String] as? Data else {
            throw CodingError.unexpectedData
        }

        return try decoder.decode(Self.self, from: accountData)
    }

    // TODO: kinda weird
    static func getAny(accountID: String, context: LAContext?) throws -> Account? {
        try UserAccount.get(accountID: accountID, context: context) ?? SharedAccount.get(accountID: accountID, context: context)
    }


    static func combinedSessionAccounts(context: LAContext? = nil) throws -> [String: SessionAccount] {
        return try allCombined(context: context).mapValues({ SessionAccount(account: $0) })
    }

    static func deleteAll() {
        Keychain.shared.deleteAll(service: Self.keychainService)
        Keychain.shared.deleteAll(service: .webauthn)
        #warning("Also fix otp keychain service")
        Keychain.shared.deleteAll(service: .otp)
        if #available(iOS 12.0, *) {
            ASCredentialIdentityStore.shared.removeAllCredentialIdentities(nil)
        }
    }

    static func allCombined(context: LAContext?, sync: Bool = false) throws -> [String: Account] {
        let userAccounts: [String: Account] = try UserAccount.all(context: context, sync: sync)
        return try userAccounts.merging(SharedAccount.all(context: context, sync: sync), uniquingKeysWith: { (userAccount, sharedAccount) -> Account in
            return userAccount
        })
    }

}
