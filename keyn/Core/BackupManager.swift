/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import Foundation

struct BackupManager {

    private let keychainService = "io.keyn.backup"
    private let endpoint = "backup"
    static let shared = BackupManager()
    
    var hasKeys: Bool {
        return Keychain.shared.has(id: KeyIdentifier.pub.identifier(for: keychainService), service: keychainService) &&
        Keychain.shared.has(id: KeyIdentifier.priv.identifier(for: keychainService), service: keychainService) &&
        Keychain.shared.has(id: KeyIdentifier.encryption.identifier(for: keychainService), service: keychainService)
    }

    private enum KeyIdentifier: String, Codable {
        case priv = "priv"
        case pub = "pub"
        case encryption = "encryption"
        
        func identifier(for keychainService: String) -> String {
            return "\(keychainService).\(self.rawValue)"
        }
    }
    
    private enum MessageIdentifier {
        static let httpMethod = "httpMethod"
        static let timestamp = "timestamp"
        static let id = "id"
        static let data = "data"
    }
    
    private init() {}

    func initialize(completion: @escaping (_ success: Bool) -> Void) throws {
        guard !hasKeys else {
            Logger.shared.warning("Tried to create backup keys while they already existed")
            return
        }
        try createEncryptionKey()
        let pubKey = try createSigningKeypair()
        
        let message = [
            MessageIdentifier.httpMethod: APIMethod.put.rawValue,
            MessageIdentifier.timestamp: String(Int(Date().timeIntervalSince1970))
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: message, options: [])
        let parameters = [
            "m": try Crypto.shared.convertToBase64(from: jsonData),
            "s": try signMessage(message: jsonData)
        ]
        
        API.shared.request(endpoint: .backup, path: pubKey, parameters: parameters, method: .put) { (_, error) in
            if let error = error {
                Logger.shared.error("Cannot initialize BackupManager.", error: error)
                completion(false)
            } else {
                completion(true)
            }
        }
    }
    
    func backup(id: String, accountData: Data) throws {
        let ciphertext = try Crypto.shared.encryptSymmetric(accountData, secretKey: try encryptionKey())

        let message = [
            MessageIdentifier.httpMethod: APIMethod.post.rawValue,
            MessageIdentifier.timestamp: String(Int(Date().timeIntervalSince1970)),
            MessageIdentifier.id: id,
            MessageIdentifier.data: try Crypto.shared.convertToBase64(from: ciphertext)
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: message, options: [])
        let parameters = [
            "m": try Crypto.shared.convertToBase64(from: jsonData),
            "s": try signMessage(message: jsonData)
        ]

        API.shared.request(endpoint: .backup, path: try publicKey(), parameters: parameters, method: .post) { (res, error) in
            if let error = error {
                Logger.shared.error("BackupManager cannot backup account data.", error: error)
            }
        }
    }
    
    func deleteAccount(accountId: String) throws {
        let message = [
            MessageIdentifier.httpMethod: APIMethod.delete.rawValue,
            MessageIdentifier.timestamp: String(Int(Date().timeIntervalSince1970)),
            MessageIdentifier.id: accountId
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: message, options: [])
        let parameters = [
            "m": try Crypto.shared.convertToBase64(from: jsonData),
            "s": try signMessage(message: jsonData)
        ]

        API.shared.request(endpoint: .backup, path: try publicKey(), parameters: parameters, method: .delete) { (_, error) in
            if let error = error {
                Logger.shared.error("BackupManager cannot delete account.", error: error)
            }
        }
    }
    
    func getBackupData(completionHandler: @escaping () -> Void) throws {
        var pubKey: String

        if !Keychain.shared.has(id: KeyIdentifier.pub.identifier(for: keychainService), service: keychainService) {
            try createEncryptionKey()
            pubKey = try createSigningKeypair()
        } else {
            pubKey = try publicKey()
        }
        
        let message = [
            MessageIdentifier.httpMethod: APIMethod.get.rawValue,
            MessageIdentifier.timestamp: String(Int(Date().timeIntervalSince1970))
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: message, options: [])
        let parameters = [
            "m": try Crypto.shared.convertToBase64(from: jsonData),
            "s": try signMessage(message: jsonData)
        ]

        API.shared.request(endpoint: .backup, path: pubKey, parameters: parameters, method: .get, completionHandler: { (dict, error) in
            if let error = error {
                Logger.shared.error("BackupManager cannot get backup data.", error: error)
                return
            }

            guard let dict = dict else {
                return
            }

            for (id, data) in dict {
                if let base64Data = data as? String {
                    do {
                        let ciphertext = try Crypto.shared.convertFromBase64(from: base64Data)
                        let accountData = try Crypto.shared.decryptSymmetric(ciphertext, secretKey: try self.encryptionKey())
                        try Account.save(accountData: accountData, id: id)
                    } catch {
                        print(error)
                        Logger.shared.error("Could not restore account.", error: error)
                    }
                }
            }
            Logger.shared.analytics("Accunts restored", code: .accountsRestored, userInfo: ["accounts": dict.count])
            completionHandler()
        })
    }
    
    func signMessage(message: Data) throws -> String {
        let signature = try Crypto.shared.sign(message: message, privKey: try privateKey())
        let base64Signature = try Crypto.shared.convertToBase64(from: signature)

        return base64Signature
    }
    
    func deleteAllKeys() {
        Keychain.shared.deleteAll(service: keychainService)
    }

    // MARK: - Private
    
    private func encryptionKey() throws -> Data {
        return try Keychain.shared.get(id: KeyIdentifier.encryption.identifier(for: keychainService), service: keychainService)
    }
    
    private func publicKey() throws -> String {
        let pubKey = try Keychain.shared.get(id: KeyIdentifier.pub.identifier(for: keychainService), service: keychainService)
        let base64PubKey = try Crypto.shared.convertToBase64(from: pubKey)
        return base64PubKey
    }
    
    private func privateKey() throws -> Data {
        return try Keychain.shared.get(id: KeyIdentifier.priv.identifier(for: keychainService), service: keychainService)
    }
    
    private func createSigningKeypair() throws -> String {
        let keyPair = try Crypto.shared.createSigningKeyPair(seed: try Seed.getBackupSeed())
        try Keychain.shared.save(id: KeyIdentifier.pub.identifier(for: keychainService), service: keychainService, secretData: keyPair.pubKey, classification: .restricted)
        try Keychain.shared.save(id: KeyIdentifier.priv.identifier(for: keychainService), service: keychainService, secretData: keyPair.privKey, classification: .secret)
        let base64PubKey = try Crypto.shared.convertToBase64(from: keyPair.pubKey)
        return base64PubKey
    }
    
    private func createEncryptionKey() throws {
        guard let contextData = "backup".data(using: .utf8) else {
            throw CodingError.stringDecoding
        }
        
        let encryptionKey = try Crypto.shared.deriveKey(keyData: try Seed.getBackupSeed(), context: contextData)
        try Keychain.shared.save(id: KeyIdentifier.encryption.identifier(for: keychainService), service: keychainService, secretData: encryptionKey, classification: .secret)
    }

}
