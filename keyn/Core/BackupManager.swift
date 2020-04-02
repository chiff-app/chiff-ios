/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import Foundation
import LocalAuthentication
import PromiseKit

struct BackupManager {

    static var hasKeys: Bool {
        return Keychain.shared.has(id: KeyIdentifier.pub.identifier(for: .backup), service: .backup) &&
        Keychain.shared.has(id: KeyIdentifier.priv.identifier(for: .backup), service: .backup) &&
        Keychain.shared.has(id: KeyIdentifier.encryption.identifier(for: .backup), service: .backup)
    }

    private static let CRYPTO_CONTEXT = "keynback"

    private enum MessageIdentifier {
        static let httpMethod = "httpMethod"
        static let timestamp = "timestamp"
        static let id = "id"
        static let data = "data"
        static let token = "token"
        static let endpoint = "endpoint"
        static let environment = "environment"
    }

    static func initialize(seed: Data, context: LAContext?) -> Promise<Void> {
        do {
            guard !hasKeys else {
                Logger.shared.warning("Tried to create backup keys while they already existed")
                return .value(())
            }
            deleteKeys()
            NotificationManager.shared.deleteKeys()
            try createEncryptionKey(seed: seed)
            let (privKey, pubKey, userId) = try createSigningKeypair(seed: seed)
            return firstly {
                API.shared.signedRequest(method: .post, message: ["userId": userId], path: "users/\(pubKey)", privKey: privKey, body: nil)
            }.asVoid().log("Cannot initialize BackupManager.")
        } catch {
            Logger.shared.error("Cannot initialize BackupManager.", error: error)
            return Promise(error: error)
        }
    }

    static func deleteBackupData() -> Promise<Void> {
        return firstly {
            API.shared.signedRequest(method: .delete, message: nil, path: "/users/\(try publicKey())", privKey: try privateKey(), body: nil)
        }.asVoid().log("BackupManager cannot delete account.")
    }
    
    static func getBackupData(seed: Data, context: LAContext) throws -> Promise<(Int,Int,Int,Int)> {
        if !Keychain.shared.has(id: KeyIdentifier.pub.identifier(for: .backup), service: .backup) {
            try createEncryptionKey(seed: seed)
            _ = try createSigningKeypair(seed: seed)
        }
        return firstly {
            when(fulfilled:
                UserAccount.restore(context: context),
                TeamSession.restore(context: context))
        }.then { result in
            TeamSession.updateAllTeamSessions(pushed: false, logo: true, backup: false).map { _ in
                return result
            }
        }.map { result in
            let ((accountsSucceeded, accountsFailed), (sessionsSucceeded, sessionsFailed)) = result
            Properties.accountCount = accountsSucceeded
            return (accountsSucceeded + accountsFailed, accountsFailed, sessionsSucceeded + sessionsFailed, sessionsFailed)
        }
    }

    static func moveToProduction() -> Promise<Void> {
        return firstly {
            API.shared.signedRequest(method: .patch, message: nil, path: "users/\(try publicKey())", privKey: try privateKey(), body: nil)
        }.asVoid().log("BackupManager cannot move backup data.")
    }

    static func deleteKeys() {
        Keychain.shared.deleteAll(service: .backup)
    }

    static func publicKey() throws -> String {
        guard let pubKey = try Keychain.shared.get(id: KeyIdentifier.pub.identifier(for: .backup), service: .backup) else {
            throw KeychainError.notFound
        }
        let base64PubKey = try Crypto.shared.convertToBase64(from: pubKey)
        return base64PubKey
    }
    
    static func privateKey() throws -> Data {
        guard let privKey = try Keychain.shared.get(id: KeyIdentifier.priv.identifier(for: .backup), service: .backup) else {
            throw KeychainError.notFound
        }
        return privKey
    }

    // MARK: - Private
    private static func createSigningKeypair(seed: Data) throws -> (Data, String, String) {
        let keyPair = try Crypto.shared.createSigningKeyPair(seed: seed)
        try Keychain.shared.save(id: KeyIdentifier.pub.identifier(for: .backup), service: .backup, secretData: keyPair.pubKey)
        try Keychain.shared.save(id: KeyIdentifier.priv.identifier(for: .backup), service: .backup, secretData: keyPair.privKey)
        let base64PubKey = try Crypto.shared.convertToBase64(from: keyPair.pubKey)
        let userId = "\(base64PubKey)_KEYN_USER_ID".sha256
        Properties.userId = userId
        return (keyPair.privKey, base64PubKey, userId)
    }
    
    private static func createEncryptionKey(seed: Data) throws {
        let encryptionKey = try Crypto.shared.deriveKey(keyData: seed, context: CRYPTO_CONTEXT)
        try Keychain.shared.save(id: KeyIdentifier.encryption.identifier(for: .backup), service: .backup, secretData: encryptionKey)
    }

}
