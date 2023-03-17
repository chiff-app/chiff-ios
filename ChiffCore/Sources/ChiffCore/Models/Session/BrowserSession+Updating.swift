//
//  BrowserSession+Updating.swift
//  ChiffCore
//
//  Copyright: see LICENSE.md
//

import Foundation
import PromiseKit

public extension BrowserSession {

    /// Update a single `SessionAccount` in this session.
    /// - Parameter account: The updated account.
    /// - Throws: Encoding or encryption errors.
    func updateSessionAccount(account: SessionAccount) throws -> Promise<Void> {
        return try updateSessionObject(object: account)
    }

    /// Update a single `SessionAccount` in this session.
    /// - Parameter account: The updated account.
    /// - Throws: Encoding or encryption errors.
    func updateSSHIdentity(identity: SSHSessionIdentity) throws -> Promise<Void> {
        guard browser == .cli else {
            throw SessionError.invalid
        }
        return try updateSessionObject(object: identity)
    }

    /// Update multiple session accounts for this session.
    /// - Parameter accounts: A dictionary of accounts, where the key is the id.
    func updateSessionAccounts(accounts: [String: SessionAccount]) -> Promise<Void> {
        do {
            let encryptedAccounts: [String: String] = try accounts.mapValues {
                let data = try JSONEncoder().encode($0)
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

    /// Delete a single session account from this session.
    /// - Parameter accountId: The account id.
    func deleteAccount(accountId: String) -> Promise<Void> {
        return firstly {
            API.shared.signedRequest(path: "sessions/\(signingPubKey)/accounts/\(accountId)", method: .delete, privKey: try signingPrivKey(), message: ["id": accountId])
        }.asVoid().log("Failed to delete session account.")
    }

    // MARK: - Static methods
    
    /// Update the session data for all sessions.
    static func updateAllSessionData() -> Promise<Void> {
        do {
            let teamSessions = try TeamSession.all()
            let wasAdmin = teamSessions.contains(where: { $0.isAdmin })
            let organisationKey = teamSessions.first?.organisationKey
            let organisationType = teamSessions.first?.type
            let isAdmin = teamSessions.contains(where: { $0.isAdmin })
            return updateAllSessionData(organisationKey: organisationKey, organisationType: organisationType, isAdmin: isAdmin)
        } catch {
            return Promise(error: error)
        }
    }

    /// Update the session data for all sessions.
    /// - Parameters:
    ///   - organisationKey: The organisation key to add.
    ///   - organisationType: The organisation type to add.
    ///   - isAdmin: Whether this user is admin in at least one team.
    static func updateAllSessionData(organisationKey: Data?, organisationType: OrganisationType?, isAdmin: Bool) -> Promise<Void> {
        return firstly {
            when(fulfilled: try all().map { try $0.updateSessionData(organisationKey: organisationKey, organisationType: organisationType, isAdmin: isAdmin) })
        }.asVoid().log("Failed to update session data.")
    }

    // MARK: - Private functions

    private func updateSessionData(organisationKey: Data?, organisationType: OrganisationType?, isAdmin: Bool) throws -> Promise<Void> {
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
    
    /// Encrypt the data for this session with the session's shared key.
    /// - Parameters:
    ///   - organisationKey: The organisation key to add to data.
    ///   - organisationType: The orgaanisation type to add to the data.
    ///   - isAdmin: Whether this user is admin in at least one team.
    ///   - migrated: Whether this beta user has been migrated to production.
    /// - Throws: Encryption errors.
    private func encryptSessionData(organisationKey: Data?, organisationType: OrganisationType?, isAdmin: Bool) throws -> String {
        var data: [String: Any] = [
            "environment": Properties.environment.rawValue,
            "verify": Properties.extraVerification,
            "errorLogging": Properties.errorLogging,
            "analyticsLogging": Properties.analyticsLogging,
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

    private func updateSessionObject<T: SessionObject>(object: T) throws -> Promise<Void> {
        let data = try JSONEncoder().encode(object)
        let ciphertext = try Crypto.shared.encrypt(data, key: sharedKey())
        let message = [
            "id": object.id,
            "data": ciphertext.base64
        ]
        return API.shared.signedRequest(path: "sessions/\(signingPubKey)/accounts/\(object.id)",
                                 method: .put,
                                 privKey: try signingPrivKey(),
                                 message: message)
            .asVoid()
            .log("Failed to update session account")
    }

}
