/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import Foundation
import LocalAuthentication
import DeviceCheck

struct BackupManager {

    private let CRYPTO_CONTEXT = "keynback"
    static let shared = BackupManager()
    
    var hasKeys: Bool {
        return Keychain.shared.has(id: KeyIdentifier.pub.identifier(for: .backup), service: .backup) &&
        Keychain.shared.has(id: KeyIdentifier.priv.identifier(for: .backup), service: .backup) &&
        Keychain.shared.has(id: KeyIdentifier.encryption.identifier(for: .backup), service: .backup)
    }
    
    private enum MessageIdentifier {
        static let httpMethod = "httpMethod"
        static let timestamp = "timestamp"
        static let id = "id"
        static let data = "data"
        static let token = "token"
        static let endpoint = "endpoint"
        static let environment = "environment"
    }
    
    private init() {}

    func initialize(seed: Data, context: LAContext?, completionHandler: @escaping (Result<Void, Error>) -> Void) {
        do {
            guard !hasKeys else {
                Logger.shared.warning("Tried to create backup keys while they already existed")
                return
            }
            deleteAllKeys()
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
                API.shared.signedRequest(endpoint: .backup, method: .put, message: message, pubKey: pubKey, privKey: privKey, body: nil) { result in
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
    
    func backup(account: BackupAccount, completionHandler: @escaping (_ result: Bool) -> Void) {
        do {
            let accountData = try JSONEncoder().encode(account)
            let ciphertext = try Crypto.shared.encryptSymmetric(accountData, secretKey: try Keychain.shared.get(id: KeyIdentifier.encryption.identifier(for: .backup), service: .backup))

            let message = [
                MessageIdentifier.id: account.id,
                MessageIdentifier.data: ciphertext.base64
            ]
            API.shared.signedRequest(endpoint: .backup, method: .post, message: message, pubKey: try publicKey(), privKey: try privateKey(), body: nil) { result in
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
    
    func deleteAccount(accountId: String) throws {
        API.shared.signedRequest(endpoint: .backup, method: .delete, message: [MessageIdentifier.id: accountId], pubKey: try publicKey(), privKey: try privateKey(), body: nil) { result in
            if case let .failure(error) = result {
                Logger.shared.error("BackupManager cannot delete account.", error: error)
            }
        }
    }

    func deleteAllAccounts(completionHandler: @escaping (Result<Void, Error>) -> Void) {
        do {
            API.shared.signedRequest(endpoint: .backup, method: .delete, message: nil, pubKey: APIEndpoint.deleteAll(for: try publicKey()), privKey: try privateKey(), body: nil) { result in
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
    
    func getBackupData(seed: Data, context: LAContext, completionHandler: @escaping (Result<(Int,Int), Error>) -> Void) throws {
        var pubKey: String

        if !Keychain.shared.has(id: KeyIdentifier.pub.identifier(for: .backup), service: .backup) {
            try createEncryptionKey(seed: seed)
            (_, pubKey, _) = try createSigningKeypair(seed: seed)
        } else {
            pubKey = try publicKey()
        }
        API.shared.signedRequest(endpoint: .backup, method: .get, message: nil, pubKey: pubKey, privKey: try privateKey(), body: nil) { result in
            switch result {
            case .success(let dict):
                var failedAccounts = [String]()
                for (id, data) in dict {
                    if let base64Data = data as? String {
                        do {
                            let ciphertext = try Crypto.shared.convertFromBase64(from: base64Data)
                            let accountData = try Crypto.shared.decryptSymmetric(ciphertext, secretKey: try Keychain.shared.get(id: KeyIdentifier.encryption.identifier(for: .backup), service: .backup))
                            try Account.save(accountData: accountData, id: id, context: context)
                        } catch {
                            failedAccounts.append(id)
                            Logger.shared.error("Could not restore account.", error: error)
                        }
                    }
                }
                Properties.accountCount = dict.count - failedAccounts.count
                completionHandler(.success((dict.count, failedAccounts.count)))
            case .failure(let error):
                Logger.shared.error("BackupManager cannot get backup data.", error: error)
                completionHandler(.failure(error))
            }
        }
    }

    func deleteAllKeys() {
        Keychain.shared.deleteAll(service: .aws)
        Keychain.shared.deleteAll(service: .backup)
    }

    func publicKey() throws -> String {
        let pubKey = try Keychain.shared.get(id: KeyIdentifier.pub.identifier(for: .backup), service: .backup)
        let base64PubKey = try Crypto.shared.convertToBase64(from: pubKey)
        return base64PubKey
    }
    
    func privateKey() throws -> Data {
        return try Keychain.shared.get(id: KeyIdentifier.priv.identifier(for: .backup), service: .backup)
    }

    // MARK: - Private
    
    private func createSigningKeypair(seed: Data) throws -> (Data, String, String) {
        let keyPair = try Crypto.shared.createSigningKeyPair(seed: seed)
        try Keychain.shared.save(id: KeyIdentifier.pub.identifier(for: .backup), service: .backup, secretData: keyPair.pubKey)
        try Keychain.shared.save(id: KeyIdentifier.priv.identifier(for: .backup), service: .backup, secretData: keyPair.privKey)
        let base64PubKey = try Crypto.shared.convertToBase64(from: keyPair.pubKey)
        let userId = "\(base64PubKey)_KEYN_USER_ID".sha256
        Properties.userId = userId
        return (keyPair.privKey, base64PubKey, userId)
    }
    
    private func createEncryptionKey(seed: Data) throws {
        let encryptionKey = try Crypto.shared.deriveKey(keyData: seed, context: CRYPTO_CONTEXT)
        try Keychain.shared.save(id: KeyIdentifier.encryption.identifier(for: .backup), service: .backup, secretData: encryptionKey)
    }

}
