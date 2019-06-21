/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import Foundation
import LocalAuthentication

struct BackupManager {

    private let CRYPTO_CONTEXT = "keynback"
    static let shared = BackupManager()
    
    var hasKeys: Bool {
        return Keychain.shared.has(id: KeyIdentifier.pub.identifier(for: .backup), service: .backup) &&
        Keychain.shared.has(id: KeyIdentifier.priv.identifier(for: .backup), service: .backup) &&
        Keychain.shared.has(id: KeyIdentifier.encryption.identifier(for: .backup), service: .backup)
    }

    private enum KeyIdentifier: String, Codable {
        case priv = "priv"
        case pub = "pub"
        case encryption = "encryption"

        func identifier(for keychainService: KeychainService) -> String {
            return "\(keychainService.rawValue).\(self.rawValue)"
        }
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

    func initialize(seed: Data, context: LAContext?, completionHandler: @escaping (_ error: Error?) -> Void) {
        do {
            guard !hasKeys else {
                Logger.shared.warning("Tried to create backup keys while they already existed")
                return
            }
            deleteAllKeys()
            try createEncryptionKey(seed: seed)
            let (privKey, pubKey) = try createSigningKeypair(seed: seed)

            API.shared.signedRequest(endpoint: .backup, method: .put, pubKey: pubKey, privKey: privKey) { (_, error) in
                if let error = error {
                    Logger.shared.error("Cannot initialize BackupManager.", error: error)
                    completionHandler(error)
                } else {
                    completionHandler(nil)
                }
            }
        } catch {
            Logger.shared.error("Cannot initialize BackupManager.", error: error)
            completionHandler(error)
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
            API.shared.signedRequest(endpoint: .backup, method: .post, message: message, pubKey: try publicKey(), privKey: try privateKey()) { (_, error) in
                if let error = error {
                    Logger.shared.error("BackupManager cannot backup account data.", error: error)
                }
                completionHandler(error == nil)
            }
        } catch {
            completionHandler(false)
        }
    }
    
    func deleteAccount(accountId: String) throws {
        API.shared.signedRequest(endpoint: .backup, method: .delete, message: [MessageIdentifier.id: accountId], pubKey: try publicKey(), privKey: try privateKey()) { (_, error) in
            if let error = error {
                Logger.shared.error("BackupManager cannot delete account.", error: error)
            }
        }
    }

    func deleteAllAccounts(completionHandler: @escaping (_ error: Error?) -> Void) {
        do {
            API.shared.signedRequest(endpoint: .backup, method: .delete, pubKey: APIEndpoint.deleteAll(for: try publicKey()), privKey: try privateKey()) { (_, error) in
                if let error = error {
                    Logger.shared.error("BackupManager cannot delete account.", error: error)
                    completionHandler(error)
                } else {
                    completionHandler(nil)
                }
            }
        } catch {
            completionHandler(error)
        }
    }
    
    func getBackupData(seed: Data, context: LAContext, completionHandler: @escaping (_ error: Error?) -> Void) throws {
        var pubKey: String

        if !Keychain.shared.has(id: KeyIdentifier.pub.identifier(for: .backup), service: .backup) {
            try createEncryptionKey(seed: seed)
            (_, pubKey) = try createSigningKeypair(seed: seed)
        } else {
            pubKey = try publicKey()
        }
        API.shared.signedRequest(endpoint: .backup, method: .get, pubKey: pubKey, privKey: try privateKey()) { (dict, error) in
            if let error = error {
                Logger.shared.error("BackupManager cannot get backup data.", error: error)
                completionHandler(error)
                return
            }

            guard let dict = dict else {
                completionHandler(CodingError.missingData)
                return
            }

            for (id, data) in dict {
                if let base64Data = data as? String {
                    do {
                        let ciphertext = try Crypto.shared.convertFromBase64(from: base64Data)
                        let accountData = try Crypto.shared.decryptSymmetric(ciphertext, secretKey: try Keychain.shared.get(id: KeyIdentifier.encryption.identifier(for: .backup), service: .backup))
                        try Account.save(accountData: accountData, id: id, context: context)
                    } catch {
                        Logger.shared.error("Could not restore account.", error: error)
                    }
                }
            }
            Logger.shared.analytics("Accounts restored", code: .accountsRestored, userInfo: ["accounts": dict.count])
            completionHandler(nil)
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
    
    private func createSigningKeypair(seed: Data) throws -> (Data, String) {
        let keyPair = try Crypto.shared.createSigningKeyPair(seed: seed)
        try Keychain.shared.save(id: KeyIdentifier.pub.identifier(for: .backup), service: .backup, secretData: keyPair.pubKey)
        try Keychain.shared.save(id: KeyIdentifier.priv.identifier(for: .backup), service: .backup, secretData: keyPair.privKey)
        let base64PubKey = try Crypto.shared.convertToBase64(from: keyPair.pubKey)
        return (keyPair.privKey, base64PubKey)
    }
    
    private func createEncryptionKey(seed: Data) throws {
        let encryptionKey = try Crypto.shared.deriveKey(keyData: seed, context: CRYPTO_CONTEXT)
        try Keychain.shared.save(id: KeyIdentifier.encryption.identifier(for: .backup), service: .backup, secretData: encryptionKey)
    }

}
