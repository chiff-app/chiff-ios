/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import Foundation
import OneTimePassword
import LocalAuthentication
import AuthenticationServices

enum AccountError: KeynError {
    case duplicateAccountId
    case accountsNotLoaded
    case notFound
    case missingContext
    case passwordGeneration
}

protocol Account: Codable {
    var id: String { get }
    var username: String { get set }
    var sites: [Site] { get set }
    var site: Site { get }
    var passwordIndex: Int { get set }
    var passwordOffset: [Int]? { get set }
    var askToLogin: Bool? { get set }
    var askToChange: Bool? { get set }
    var synced: Bool { get }

    func backup() throws
    func delete(completionHandler: @escaping (_ error: Error?) -> Void)
}

extension Account {

    func password(context: LAContext? = nil) throws -> String {
        do {

    //         return try Keychain.shared.isSynced(id: id, service: .account)
    //     } catch {
    //         Logger.shared.error("Error get account sync info", error: error)
    //         return true // Defaults to true to prevent infinite cycles when an error occurs
    //     }

            let data = try Keychain.shared.get(id: id, service: .account, context: context)

            guard let password = String(data: data, encoding: .utf8) else {
                throw CodingError.stringEncoding
            }

            return password
        } catch {
            Logger.shared.error("Could not retrieve password from account", error: error, userInfo: nil)
            throw error
        }
    }

    func password(reason: String, context: LAContext? = nil, type: AuthenticationType, completionHandler: @escaping (Result<String, Error>) -> Void) {
        Keychain.shared.get(id: id, service: .account, reason: reason, with: context, authenticationType: type) { (result) in
            switch result {
            case .success(let data):
                guard let password = String(data: data, encoding: .utf8) else {
                    return completionHandler(.failure(CodingError.stringEncoding))
                }
                completionHandler(.success(password))
            case .failure(let error): completionHandler(.failure(error))
            }
        }
    }

    func oneTimePasswordToken() throws -> Token? {
        guard let urlDataDict = try Keychain.shared.attributes(id: id, service: .otp, context: nil) else {
            return nil
        }
        let secret = try Keychain.shared.get(id: id, service: .otp, context: nil)
        guard let urlData = urlDataDict[kSecAttrGeneric as String] as? Data, let urlString = String(data: urlData, encoding: .utf8),
            let url = URL(string: urlString) else {
                throw CodingError.unexpectedData
        }

        return Token(url: url, secret: secret)
    }

    func hasOtp() -> Bool {
        return Keychain.shared.has(id: id, service: .otp)
    }

    func update(secret: Data?) throws {
        let accountData = try PropertyListEncoder().encode(self)
        try Keychain.shared.update(id: id, service: .account, secretData: secret, objectData: accountData, context: nil)
        try backup()
        try BrowserSession.all().forEach({ try $0.updateAccountList(account: self) })
        saveToIdentityStore()
    }

    func save(password: String) throws {
        let accountData = try PropertyListEncoder().encode(self)
        try Keychain.shared.save(id: id, service: .account, secretData: password.data, objectData: accountData)
        try backup()
        try BrowserSession.all().forEach({ try $0.updateAccountList(account: self) })
        saveToIdentityStore()
        Properties.accountCount += 1
    }

    // MARK: - Static functions

    static func all(context: LAContext?, sync: Bool = false) throws -> [String: Self] {
        guard let dataArray = try Keychain.shared.all(service: .account, context: context) else {
            return [:]
        }
        Properties.accountCount = dataArray.count
        let decoder = PropertyListDecoder()

        return Dictionary(uniqueKeysWithValues: try dataArray.map { (dict) in
            guard let accountData = dict[kSecAttrGeneric as String] as? Data else {
                throw CodingError.unexpectedData
            }
            var account = try decoder.decode(Self.self, from: accountData)
            if sync {
                if account.version == 0 {
                    account.updateVersion(context: context)
                } else if !account.synced {
                    try? account.backup()
                }
            }
            return (account.id, account)
            })
    }

    static func get(accountID: String, context: LAContext?) throws -> Self? {
        guard let dict = try Keychain.shared.attributes(id: accountID, service: .account, context: context) else {
            return nil
        }

        let decoder = PropertyListDecoder()

        guard let accountData = dict[kSecAttrGeneric as String] as? Data else {
            throw CodingError.unexpectedData
        }

        return try decoder.decode(Self.self, from: accountData)
    }

    static func accountList(context: LAContext? = nil) throws -> AccountList {
        return try all(context: context).mapValues({ JSONAccount(account: $0) })
    }

    static func deleteAll() {
        Keychain.shared.deleteAll(service: .account)
        Keychain.shared.deleteAll(service: .otp)
        if #available(iOS 12.0, *) {
            ASCredentialIdentityStore.shared.removeAllCredentialIdentities(nil)
        }
    }

    // MARK: - AuthenticationServices

    func saveToIdentityStore() {
        if #available(iOS 12.0, *) {
            ASCredentialIdentityStore.shared.getState { (state) in
                if !state.isEnabled {
                    return
                } else if state.supportsIncrementalUpdates {
                    let service = ASCredentialServiceIdentifier(identifier: self.site.url, type: ASCredentialServiceIdentifier.IdentifierType.URL)
                    let identity = ASPasswordCredentialIdentity(serviceIdentifier: service, user: self.username, recordIdentifier: self.id)
                    ASCredentialIdentityStore.shared.saveCredentialIdentities([identity], completion: nil)
                } else if let accounts = try? Self.all(context: nil) {
                    let identities = accounts.values.map { (account) -> ASPasswordCredentialIdentity in
                        let service = ASCredentialServiceIdentifier(identifier: account.site.url, type: ASCredentialServiceIdentifier.IdentifierType.URL)
                        return ASPasswordCredentialIdentity(serviceIdentifier: service, user: account.username, recordIdentifier: account.id)
                    }
                    ASCredentialIdentityStore.shared.saveCredentialIdentities(identities, completion: nil)
                }
            }
        }
    }

    func deleteFromToIdentityStore() {
        if #available(iOS 12.0, *) {
            ASCredentialIdentityStore.shared.getState { (state) in
                if !state.isEnabled {
                    return
                } else if state.supportsIncrementalUpdates {
                    let service = ASCredentialServiceIdentifier(identifier: self.site.url, type: ASCredentialServiceIdentifier.IdentifierType.URL)
                    let identity = ASPasswordCredentialIdentity(serviceIdentifier: service, user: self.username, recordIdentifier: self.id)
                    ASCredentialIdentityStore.shared.removeCredentialIdentities([identity], completion: nil)
                } else {
                    ASCredentialIdentityStore.shared.removeAllCredentialIdentities({ (result, error) in
                        if let error = error {
                            Logger.shared.error("Error deleting credentials from identity store", error: error)
                        } else if result, let accounts = try? Self.all(context: nil) {
                            let identities = accounts.values.map { (account) -> ASPasswordCredentialIdentity in
                                let service = ASCredentialServiceIdentifier(identifier: account.site.url, type: ASCredentialServiceIdentifier.IdentifierType.URL)
                                return ASPasswordCredentialIdentity(serviceIdentifier: service, user: account.username, recordIdentifier: account.id)
                            }
                            ASCredentialIdentityStore.shared.saveCredentialIdentities(identities, completion: nil)
                        }
                    })
                }
            }
        }
    }
