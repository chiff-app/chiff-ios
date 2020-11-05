//
//  BrowserSession+Updating.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import Foundation
import PromiseKit

extension BrowserSession {

    // MARK: - Static methods

    static func updateAllSessionData(organisationKey: Data?, organisationType: OrganisationType?, isAdmin: Bool) -> Promise<Void> {
        return firstly {
            when(fulfilled: try all().map { try $0.updateSessionData(organisationKey: organisationKey, organisationType: organisationType, isAdmin: isAdmin) })
        }.asVoid().log("Failed to update session data.")
    }

    func updateSessionAccount(account: Account) throws -> Promise<Void> {
        let accountData = try JSONEncoder().encode(SessionAccount(account: account))
        let ciphertext = try Crypto.shared.encrypt(accountData, key: sharedKey())
        let message = [
            "id": account.id,
            "data": ciphertext.base64
        ]
        return API.shared.signedRequest(path: "sessions/\(signingPubKey)/accounts/\(account.id)",
                                 method: .put,
                                 privKey: try signingPrivKey(),
                                 message: message)
            .asVoid()
            .log("Failed to update session account")
    }

    func updateSessionAccounts(accounts: [String: UserAccount]) -> Promise<Void> {
        do {
            let encryptedAccounts: [String: String] = try accounts.mapValues {
                let data = try JSONEncoder().encode(SessionAccount(account: $0))
                return try Crypto.shared.encrypt(data, key: sharedKey()).base64
            }
            let message: [String: Any] = [
                "httpMethod": APIMethod.put.rawValue,
                "timestamp": String(Date.now),
                "accounts": encryptedAccounts
            ]
            let jsonData = try JSONSerialization.data(withJSONObject: message, options: [])
            let signature = try Crypto.shared.signature(message: jsonData, privKey: try signingPrivKey()).base64
            return firstly {
                API.shared.request(path: "sessions/\(signingPubKey)/accounts", method: .put, signature: signature, body: jsonData)
            }.asVoid().log("Session cannot write bulk session accounts.")
        } catch {
            return Promise(error: error)
        }
    }

    func updateSessionData(organisationKey: Data?, organisationType: OrganisationType?, isAdmin: Bool) throws -> Promise<Void> {
        let message = [
            "data": try encryptSessionData(organisationKey: organisationKey, organisationType: organisationType, isAdmin: isAdmin)
        ]
        return API.shared.signedRequest(path: "sessions/\(signingPubKey)",
                                        method: .put,
                                        privKey: try signingPrivKey(),
                                        message: message)
            .asVoid()
            .log("Failed to update session data.")
    }

    func encryptSessionData(organisationKey: Data?, organisationType: OrganisationType?, isAdmin: Bool, migrated: Bool? = nil) throws -> String {
        var data: [String: Any] = [
            "environment": (migrated ?? Properties.migrated) ? Properties.Environment.prod.rawValue : Properties.environment.rawValue,
            "isAdmin": isAdmin
        ]
        if let appVersion = Properties.version {
            data["appVersion"] = appVersion
        }
        if let organisationKey = organisationKey {
            data["organisationKey"] = organisationKey.base64
        }
        if let organisationType = organisationType {
            data["organisationType"] = organisationType.rawValue
        }
        return try Crypto.shared.encrypt(JSONSerialization.data(withJSONObject: data, options: []), key: try sharedKey()).base64
    }

    func deleteAccount(accountId: String) -> Promise<Void> {
        return firstly {
            API.shared.signedRequest(path: "sessions/\(signingPubKey)/accounts/\(accountId)", method: .delete, privKey: try signingPrivKey(), message: ["id": accountId])
        }.asVoid().log("Failed to delete session account.")
    }
}
