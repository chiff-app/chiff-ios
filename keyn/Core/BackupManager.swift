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
    
    static func backup(account: BackupUserAccount, completionHandler: @escaping (_ result: Bool) -> Void) {
        do {
            let accountData = try JSONEncoder().encode(account)
            guard let key = try Keychain.shared.get(id: KeyIdentifier.encryption.identifier(for: .backup), service: .backup) else {
                throw KeychainError.notFound
            }
            let ciphertext = try Crypto.shared.encryptSymmetric(accountData, secretKey: key)

            let message = [
                MessageIdentifier.id: account.id,
                MessageIdentifier.data: ciphertext.base64
            ]
            API.shared.signedRequest(method: .put, message: message, path: "users/\(try publicKey())/accounts/\(account.id)", privKey: try privateKey(), body: nil) { result in
                switch result {
                case .success(_):
                    completionHandler(true)
                case .failure(let error):
                    Logger.shared.error("BackupManager cannot backup account data.", error: error)
                    completionHandler(false)
                }
            }
        } catch {
            completionHandler(false)
        }
    }

    static func backup(session: BackupTeamSession, completionHandler: @escaping (_ result: Bool) -> Void) {
        do {
            let sessionData = try JSONEncoder().encode(session)
            guard let key = try Keychain.shared.get(id: KeyIdentifier.encryption.identifier(for: .backup), service: .backup) else {
                throw KeychainError.notFound
            }
            let ciphertext = try Crypto.shared.encryptSymmetric(sessionData, secretKey: key)

            let message = [
                MessageIdentifier.id: session.id,
                MessageIdentifier.data: ciphertext.base64
            ]
            API.shared.signedRequest(method: .put, message: message, path: "users/\(try publicKey())/sessions/\(session.id)", privKey: try privateKey(), body: nil) { result in
                switch result {
                case .success(_):
                    completionHandler(true)
                case .failure(let error):
                    Logger.shared.error("BackupManager cannot backup account data.", error: error)
                    completionHandler(false)
                }
            }
        } catch {
            completionHandler(false)
        }
    }

    
    static func deleteAccount(accountId: String) throws {
        API.shared.signedRequest(method: .delete, message: [MessageIdentifier.id: accountId], path: "users/\(try publicKey())/accounts/\(accountId)", privKey: try privateKey(), body: nil) { result in
            if case let .failure(error) = result {
                Logger.shared.error("BackupManager cannot delete account.", error: error)
            }
        }
    }

    static func deleteSession(sessionId: String) throws {
        API.shared.signedRequest(method: .delete, message: [MessageIdentifier.id: sessionId], path: "users/\(try publicKey())/sessions/\(sessionId)", privKey: try privateKey(), body: nil) { result in
            if case let .failure(error) = result {
                Logger.shared.error("BackupManager cannot delete account.", error: error)
            }
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
        var accounts: [UserAccount] = []
        var failedAccounts: Int = 0
        var sessions: [TeamSession] = []
        var failedSessions: Int = 0
        var groupError: Error?
        group.enter()
        API.shared.signedRequest(method: .get, message: nil, path: "users/\(pubKey)/accounts", privKey: try privateKey(), body: nil) { result in
            do {
                (accounts, failedAccounts) = try self.backupDataHandler(result, context: context)
            } catch {
                if groupError == nil {
                    groupError = error
                }
            }
            group.leave()
        }
        group.enter()
        API.shared.signedRequest(method: .get, message: nil, path: "users/\(pubKey)/sessions", privKey: try privateKey(), body: nil) { result in
            do {
                (sessions, failedSessions) = try self.backupDataHandler(result, context: context)
                sessions.forEach {
                    $0.updateLogo()
                    $0.updateSharedAccounts(pushed: false) { _ in }
                }
            } catch {
                if groupError == nil {
                    groupError = error
                }
            }
            group.leave()
        }
        group.notify(queue: .main) {
            if let error = groupError {
                completionHandler(.failure(error))
            } else {
                Properties.accountCount = accounts.count - failedAccounts
                completionHandler(.success((accounts.count + failedAccounts, failedAccounts, sessions.count + failedSessions, failedSessions)))
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

    private static func backupDataHandler<T: Restorable>(_ result: Result<JSONObject, Error>, context: LAContext) throws -> ([T], Int) {
        switch result {
        case .success(let dict):
            var failed = [String]()
            let objects = dict.compactMap { (id, data) -> T? in
                if let base64Data = data as? String {
                    do {
                        let ciphertext = try Crypto.shared.convertFromBase64(from: base64Data)
                        guard let key = try Keychain.shared.get(id: KeyIdentifier.encryption.identifier(for: .backup), service: .backup) else {
                            throw KeychainError.notFound
                        }
                        let data = try Crypto.shared.decryptSymmetric(ciphertext, secretKey: key)
                        return try T.restore(data: data, id: id, context: context)
                    } catch {
                        failed.append(id)
                        Logger.shared.error("Could not restore data.", error: error)
                    }
                }
                return nil
            }
            return (objects, failed.count)
        case .failure(let error):
            Logger.shared.error("BackupManager cannot get backup data.", error: error)
            throw error
        }
    }
    
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
