/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import Foundation
import LocalAuthentication
import DeviceCheck

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

    static func initialize(seed: Data, context: LAContext?, completionHandler: @escaping (Result<Void, Error>) -> Void) {
        do {
            guard !hasKeys else {
                Logger.shared.warning("Tried to create backup keys while they already existed")
                completionHandler(.success(()))
                return
            }
            deleteKeys()
            NotificationManager.shared.deleteKeys()
            try createEncryptionKey(seed: seed)
            let (privKey, pubKey, userId) = try createSigningKeypair(seed: seed)
            DCDevice.current.generateToken { (data, error) in
                if let error = error {
                    Logger.shared.warning("Error retrieving device token.", error: error)
                }
                var message: [String: Any] = [
                    "os": "ios",
                    "userId": userId
                ]
                if let data = data {
                    message[MessageIdentifier.token] = data.base64EncodedString()
                }
                API.shared.signedRequest(method: .post, message: message, path: "users/\(pubKey)", privKey: privKey, body: nil) { result in
                    switch result {
                    case .success(_):
                        completionHandler(.success(()))
                    case .failure(let error):
                        Logger.shared.error("Cannot initialize BackupManager.", error: error)
                        completionHandler(.failure(error))
                    }
                }
            }
        } catch {
            Logger.shared.error("Cannot initialize BackupManager.", error: error)
            completionHandler(.failure(error))
        }
    }

    static func deleteBackupData(completionHandler: @escaping (Result<Void, Error>) -> Void) {
        do {
            API.shared.signedRequest(method: .delete, message: nil, path: "/users/\(try publicKey())", privKey: try privateKey(), body: nil) { result in
                switch result {
                case .success(_): completionHandler(.success(()))
                case .failure(let error):
                    Logger.shared.error("BackupManager cannot delete account.", error: error)
                    completionHandler(.failure(error))
                }
            }
        } catch {
            completionHandler(.failure(error))
        }
    }
    
    static func getBackupData(seed: Data, context: LAContext, completionHandler: @escaping (Result<(Int,Int,Int,Int), Error>) -> Void) throws {
        var pubKey: String

        if !Keychain.shared.has(id: KeyIdentifier.pub.identifier(for: .backup), service: .backup) {
            try createEncryptionKey(seed: seed)
            (_, pubKey, _) = try createSigningKeypair(seed: seed)
        } else {
            pubKey = try publicKey()
        }
        let group = DispatchGroup()
        var accountsSucceeded = 0
        var failedAccounts = 0
        var sessionsSucceeded = 0
        var failedSessions = 0
        var groupError: Error?
        group.enter()
        UserAccount.getBackupData(pubKey: pubKey, context: context) { (result) in
            switch result {
            case .success(let total, let failed):
                accountsSucceeded = total
                failedAccounts = failed
            case .failure(let error):
                groupError = error
            }
            group.leave()
        }
        group.enter()
        TeamSession.getBackupData(pubKey: pubKey, context: context) { (result) in
            switch result {
            case .success(let total, let failed):
                sessionsSucceeded = total
                failedSessions = failed
                TeamSession.updateTeamSessions(pushed: false, logo: true, backup: false) { (result) in
                    if case .failure(let error) = result {
                        groupError = error
                    }
                    group.leave()
                }
            case .failure(let error):
                groupError = error
                group.leave()
            }
        }
        group.notify(queue: .main) {
            if let error = groupError {
                completionHandler(.failure(error))
            } else {
                Properties.accountCount = accountsSucceeded
                completionHandler(.success((accountsSucceeded + failedAccounts, failedAccounts, sessionsSucceeded + failedSessions, failedSessions)))
            }
        }
    }

    static func moveToProduction(completionHandler: @escaping ((Error?) -> Void)) {
        do {
            API.shared.signedRequest(method: .patch, message: nil, path: "users/\(try publicKey())", privKey: try privateKey(), body: nil) { (result) in
                if case .failure(let error) = result {
                    Logger.shared.error("BackupManager cannot move backup data.", error: error)
                    completionHandler(error)
                } else {
                    completionHandler(nil)
                }
            }
        } catch {
            Logger.shared.error("BackupManager cannot move backup data.", error: error)
            completionHandler(error)
        }
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
