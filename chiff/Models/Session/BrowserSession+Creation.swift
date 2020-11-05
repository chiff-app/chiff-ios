//
//  BrowserSession+Creation.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import Foundation
import PromiseKit

extension BrowserSession {

    static func initiate(pairingQueueSeed: String, browserPubKey: String, browser: Browser, os: String, version: Int = 0) -> Promise<Session> {
        do {
            let keyPairForSharedKey = try Crypto.shared.createSessionKeyPair()
            let browserPubKeyData = try Crypto.shared.convertFromBase64(from: browserPubKey)
            let sharedKey = try Crypto.shared.generateSharedKey(pubKey: browserPubKeyData, privKey: keyPairForSharedKey.privKey)
            let signingKeyPair = try Crypto.shared.createSigningKeyPair(seed: sharedKey)
            let pairingKeyPair = try Crypto.shared.createSigningKeyPair(seed: Crypto.shared.convertFromBase64(from: pairingQueueSeed))
            guard let id = browserPubKey.hash else {
                throw CryptoError.hashing
            }
            let session = BrowserSession(id: id, signingPubKey: signingKeyPair.pubKey, browser: browser, title: "\(browser.rawValue.capitalizedFirstLetter) @ \(os)", version: version)
            let teamSession = try TeamSession.all().first // Get first for now, perhaps handle unlikely scenario where user belongs to multiple organisation in the future.
            let response = try BrowserPairingResponse(id: session.id, pubKey: keyPairForSharedKey.pubKey.base64, browserPubKey: browserPubKey,
                                                      version: session.version, organisationKey: teamSession?.organisationKey.base64,
                                                      organisationType: teamSession?.type, isAdmin: teamSession?.isAdmin)
            return firstly {
                try session.createQueues(signingKeyPair: signingKeyPair,
                                         sharedKey: sharedKey,
                                         isAdmin: teamSession?.isAdmin,
                                         organisationKey: teamSession?.organisationKey,
                                         organisationType: teamSession?.type)
            }.then {
                session.acknowledgeSessionStart(pairingKeyPair: pairingKeyPair, browserPubKey: browserPubKeyData, pairingResponse: response)
            }.map {
                do {
                    try session.save(key: sharedKey, signingKeyPair: signingKeyPair)
                    BrowserSession.count += 1
                    return session
                } catch is KeychainError {
                    throw SessionError.exists
                } catch is CryptoError {
                    throw SessionError.invalid
                }
            }
        } catch {
            Logger.shared.error("Error initiating session", error: error)
            return Promise(error: error)
        }
    }

    // MARK: - Private

    private func createQueues(signingKeyPair keyPair: KeyPair, sharedKey: Data, isAdmin: Bool?, organisationKey: Data?, organisationType: OrganisationType?) throws -> Promise<Void> {
        guard let deviceEndpoint = Properties.endpoint else {
            throw SessionError.noEndpoint
        }
        var data: [String: Any] = [:]
        if let appVersion = Properties.version {
            data["appVersion"] = appVersion
        }
        if let organisationKey = organisationKey {
            data["organisationKey"] = organisationKey.base64
        }
        if let organisationType = organisationType {
            data["organisationType"] = organisationType.rawValue
        }
        if let isAdmin = isAdmin {
            data["isAdmin"] = isAdmin
        }
        var message: [String: Any] = [
            "httpMethod": APIMethod.post.rawValue,
            "timestamp": String(Int(Date().timeIntervalSince1970)),
            "deviceEndpoint": deviceEndpoint,
            "data": try Crypto.shared.encrypt(JSONSerialization.data(withJSONObject: data, options: []), key: sharedKey).base64
        ]
        if let userId = Properties.userId {
            message["userId"] = userId
        }
        do {
            let userAccounts = try UserAccount.all(context: nil)
            message["userAccounts"] = try userAccounts.mapValues { (account) -> String in
                let accountData = try JSONEncoder().encode(SessionAccount(account: account))
                return try Crypto.shared.encrypt(accountData, key: sharedKey).base64
            }
            message["teamAccounts"] = try SharedAccount.all(context: nil).compactMapValues { (account) -> [String: String]? in
                guard !userAccounts.keys.contains(account.id) else {
                    return nil
                }
                let accountData = try JSONEncoder().encode(SessionAccount(account: account))
                return [
                    "data": try Crypto.shared.encrypt(accountData, key: sharedKey).base64,
                    "sessionId": account.sessionId
                ]
            }
            let jsonData = try JSONSerialization.data(withJSONObject: message, options: [])
            let signature = try Crypto.shared.signature(message: jsonData, privKey: keyPair.privKey).base64
            return API.shared.request(path: "sessions/\(keyPair.pubKey.base64)", method: .post, signature: signature, body: jsonData).asVoid().log("Cannot create SQS queues and SNS endpoint.")
        } catch {
            return Promise(error: error)
        }
    }

}
