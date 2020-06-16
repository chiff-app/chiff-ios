/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import Foundation
import OneTimePassword
import LocalAuthentication
import AuthenticationServices
import PromiseKit

enum AccountError: Error {
    case duplicateAccountId
    case accountsNotLoaded
    case notFound
    case missingContext
    case passwordGeneration
    case tokenRetrieval
    case wrongRpId
    case noWebAuthn
    case notTOTP
}

protocol Account: BaseAccount {
    var askToLogin: Bool? { get set }
    var askToChange: Bool? { get set }
    var synced: Bool { get }
    var enabled: Bool { get }
    var timesUsed: Int { get set }
    var lastTimeUsed: Date? { get set }

    static var keychainService: KeychainService { get }

    func delete() -> Promise<Void>
    func update(secret: Data?, backup: Bool) throws
}

extension Account {

    var hasOtp: Bool {
        return Keychain.shared.has(id: id, service: .otp)
    }

    func notes(context: LAContext? = nil) throws -> String? {
        guard let data = try Keychain.shared.get(id: id, service: .notes, context: context) else {
            return nil
        }
        guard let notes = String(data: data, encoding: .utf8) else {
            throw CodingError.stringEncoding
        }
        return notes
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
            if sync, var account = account as? UserAccount {
                if account.version == 0 {
                    account.updateVersion(context: context)
                } else if !account.synced {
                    let _ = try? account.backup()
                }
            }
            return (account.id, account)
            })
    }

    static func get(id: String, context: LAContext?) throws -> Self? {
        guard let dict = try Keychain.shared.attributes(id: id, service: Self.keychainService, context: context) else {
            return nil
        }

        let decoder = PropertyListDecoder()

        guard let accountData = dict[kSecAttrGeneric as String] as? Data else {
            throw CodingError.unexpectedData
        }

        return try decoder.decode(Self.self, from: accountData)
    }

    func deleteSync() throws {
        try Keychain.shared.delete(id: id, service: Self.keychainService)
        try? Keychain.shared.delete(id: id, service: .webauthn)
        try? Keychain.shared.delete(id: id, service: .notes)
        try? Keychain.shared.delete(id: id, service: .otp)
        try BrowserSession.all().forEach({ $0.deleteAccount(accountId: id) })
        self.deleteFromToIdentityStore()
    }

    // TODO: kinda weird
    static func getAny(id: String, context: LAContext?) throws -> Account? {
        try UserAccount.get(id: id, context: context) ?? SharedAccount.get(id: id, context: context)
    }


    static func combinedSessionAccounts(context: LAContext? = nil) throws -> [String: SessionAccount] {
        return try allCombined(context: context).mapValues({ SessionAccount(account: $0) })
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

    static func allCombined(context: LAContext?, sync: Bool = false) throws -> [String: Account] {
        let userAccounts: [String: Account] = try UserAccount.all(context: context, sync: sync)
        return try userAccounts.merging(SharedAccount.all(context: context, sync: sync), uniquingKeysWith: { (userAccount, sharedAccount) -> Account in
            return userAccount
        })
    }

}
