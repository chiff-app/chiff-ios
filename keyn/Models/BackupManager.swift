/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import Foundation

struct BackupManager {
    private let keychainService = "io.keyn.backup"
    private let endpoint = "backup"
    static let shared = BackupManager()

    private enum KeyIdentifier: String, Codable {
        case priv = "priv"
        case pub = "pub"
        case encryption = "encryption"
        
        func identifier(for keychainService: String) -> String {
            return "\(keychainService).\(self.rawValue)"
        }
    }
    
    private init() {}
    
    func initialize() throws {
        var pubKey: String
        if !Keychain.shared.has(id: KeyIdentifier.pub.identifier(for: keychainService), service: keychainService) {
            try createEncryptionKey()
            pubKey = try createSigningKeypair()
        } else {
            pubKey = try publicKey()
        }
        let message = [
            "type": APIRequestType.put.rawValue,
            "timestamp": String(Int(Date().timeIntervalSince1970))
        ]
        let jsonData = try JSONSerialization.data(withJSONObject: message, options: [])
        let parameters = [
            "m": try Crypto.shared.convertToBase64(from: jsonData),
            "s": try signMessage(message: jsonData)
        ]
        try API.shared.put(type: .backup, path: pubKey, parameters: parameters)
    }
    
    func backup(id: String, accountData: Data) throws {
        let ciphertext = try Crypto.shared.encryptSymmetric(accountData, secretKey: try encryptionKey())
        let message = [
            "type": APIRequestType.post.rawValue,
            "timestamp": String(Int(Date().timeIntervalSince1970)),
            "id": id,
            "data": try Crypto.shared.convertToBase64(from: ciphertext)
        ]
        let jsonData = try JSONSerialization.data(withJSONObject: message, options: [])
        let parameters = [
            "m": try Crypto.shared.convertToBase64(from: jsonData),
            "s": try signMessage(message: jsonData)
        ]
        try API.shared.post(type: .backup, path: try publicKey(), parameters: parameters)
    }
    
    func deleteAccount(accountId: String) throws {
        let message = [
            "type": APIRequestType.delete.rawValue,
            "timestamp": String(Int(Date().timeIntervalSince1970)),
            "id": accountId
        ]
        let jsonData = try JSONSerialization.data(withJSONObject: message, options: [])
        let parameters = [
            "m": try Crypto.shared.convertToBase64(from: jsonData),
            "s": try signMessage(message: jsonData)
        ]
        try API.shared.delete(type: .backup, path: try publicKey(), parameters: parameters)
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
            "type": APIRequestType.get.rawValue,
            "timestamp": String(Int(Date().timeIntervalSince1970))
        ]
        let jsonData = try JSONSerialization.data(withJSONObject: message, options: [])
        let parameters = [
            "m": try Crypto.shared.convertToBase64(from: jsonData),
            "s": try signMessage(message: jsonData)
        ]
        try API.shared.get(type: .backup, path: pubKey, parameters: parameters, completionHandler: { (dict) in
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
            Logger.shared.info("Accunts restored", userInfo: ["code": AnalyticsMessage.accountsRestored.rawValue, "accounts": dict.count])
            completionHandler()
        })
    }
    
    func signMessage(message: String) throws -> String {
        guard let messageData = message.data(using: .utf8) else {
            throw KeynError.stringDecoding
        }
        let signedMessage = try Crypto.shared.sign(message: messageData, privKey: try privateKey())
        let base64Message = try Crypto.shared.convertToBase64(from: signedMessage)
        return base64Message
    }
    
    func signMessage(message: Data) throws -> String {
        let signature = try Crypto.shared.sign(message: message, privKey: try privateKey())
        let base64Signature = try Crypto.shared.convertToBase64(from: signature)
        return base64Signature
    }
    
    func deleteAllKeys() {
        Keychain.shared.deleteAll(service: keychainService)
    }
    
    private func createEncryptionKey() throws {
        guard let contextData = "backup".data(using: .utf8) else {
            throw KeynError.stringDecoding
        }
        let encryptionKey = try Crypto.shared.deriveKey(keyData: try Seed.getBackupSeed(), context: contextData)
        try Keychain.shared.save(secretData: encryptionKey, id: KeyIdentifier.encryption.identifier(for: keychainService), service: keychainService, classification: .secret)
    }
    
    private func encryptionKey() throws -> Data {
        return try Keychain.shared.get(id: KeyIdentifier.encryption.identifier(for: keychainService), service: keychainService)
    }
    
    private func publicKey() throws -> String {
        let pubKey = try Keychain.shared.get(id: KeyIdentifier.pub.identifier(for: keychainService), service: keychainService)
        let base64PubKey = try Crypto.shared.convertToBase64(from: pubKey)
        return base64PubKey
    }
    
    private func privateKey() throws -> Data {
        let privKey = try Keychain.shared.get(id: KeyIdentifier.priv.identifier(for: keychainService), service: keychainService)
        return privKey
    }
    
    private func createSigningKeypair() throws -> String {
        let keyPair = try Crypto.shared.createSigningKeyPair(seed: try Seed.getBackupSeed())
        try Keychain.shared.save(secretData: keyPair.publicKey.data, id: KeyIdentifier.pub.identifier(for: keychainService), service: keychainService, classification: .restricted)
        try Keychain.shared.save(secretData: keyPair.secretKey.data, id: KeyIdentifier.priv.identifier(for: keychainService), service: keychainService, classification: .secret)
        
        let base64PubKey = try Crypto.shared.convertToBase64(from: keyPair.publicKey.data)
        return base64PubKey
    }
}
