//
//  BackupManager.swift
//  keyn
//
//  Created by bas on 22/04/2018.
//  Copyright © 2018 keyn. All rights reserved.
//

import Foundation
import JustLog

struct BackupManager {
    
    private let keychainService = "io.keyn.backup"
    private let endpoint = "backup"
    static let sharedInstance = BackupManager()
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
        if !Keychain.sharedInstance.has(id: KeyIdentifier.pub.identifier(for: keychainService), service: keychainService) {
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
            "m": try Crypto.sharedInstance.convertToBase64(from: jsonData),
            "s": try signMessage(message: jsonData)
        ]
        try API.sharedInstance.put(type: .backup, path: pubKey, parameters: parameters)
    }
    
    func backup(id: String, accountData: Data) throws {
        let ciphertext = try Crypto.sharedInstance.encryptSymmetric(accountData, secretKey: try encryptionKey())
        let message = [
            "type": APIRequestType.post.rawValue,
            "timestamp": String(Int(Date().timeIntervalSince1970)),
            "id": id,
            "data": try Crypto.sharedInstance.convertToBase64(from: ciphertext)
        ]
        let jsonData = try JSONSerialization.data(withJSONObject: message, options: [])
        let parameters = [
            "m": try Crypto.sharedInstance.convertToBase64(from: jsonData),
            "s": try signMessage(message: jsonData)
        ]
        try API.sharedInstance.post(type: .backup, path: try publicKey(), parameters: parameters)
    }
    
    func deleteAccount(accountId: String) throws {
        let message = [
            "type": APIRequestType.delete.rawValue,
            "timestamp": String(Int(Date().timeIntervalSince1970)),
            "id": accountId
        ]
        let jsonData = try JSONSerialization.data(withJSONObject: message, options: [])
        let parameters = [
            "m": try Crypto.sharedInstance.convertToBase64(from: jsonData),
            "s": try signMessage(message: jsonData)
        ]
        try API.sharedInstance.delete(type: .backup, path: try publicKey(), parameters: parameters)
    }
    
    func getBackupData(completionHandler: @escaping () -> Void) throws {
        var pubKey: String
        if !Keychain.sharedInstance.has(id: KeyIdentifier.pub.identifier(for: keychainService), service: keychainService) {
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
            "m": try Crypto.sharedInstance.convertToBase64(from: jsonData),
            "s": try signMessage(message: jsonData)
        ]
        try API.sharedInstance.get(type: .backup, path: pubKey, parameters: parameters, completionHandler: { (dict) in
            for (id, data) in dict {
                if let base64Data = data as? String {
                    do {
                        let ciphertext = try Crypto.sharedInstance.convertFromBase64(from: base64Data)
                        let accountData = try Crypto.sharedInstance.decryptSymmetric(ciphertext, secretKey: try self.encryptionKey())
                        try Account.save(accountData: accountData, id: id)
                    } catch {
                        print(error)
                        Logger.shared.error("Could not restore account.", error: error as NSError)
                    }
                }
            }
            Logger.shared.info("Accunts restored", userInfo: ["code": AnalyticsMessage.accountsRestored.rawValue, "accounts": dict.count])
            completionHandler()
        })
    }
    
    func signMessage(message: String) throws -> String {
        guard let messageData = message.data(using: .utf8) else {
            throw CryptoError.convertToData
        }
        let signedMessage = try Crypto.sharedInstance.sign(message: messageData, privKey: try privateKey())
        let base64Message = try Crypto.sharedInstance.convertToBase64(from: signedMessage)
        return base64Message
    }
    
    func signMessage(message: Data) throws -> String {
        let signature = try Crypto.sharedInstance.sign(message: message, privKey: try privateKey())
        let base64Signature = try Crypto.sharedInstance.convertToBase64(from: signature)
        return base64Signature
    }
    
    func deleteAllKeys() {
        Keychain.sharedInstance.deleteAll(service: keychainService)
    }
    
    private func createEncryptionKey() throws {
        guard let contextData = "backup".data(using: .utf8) else {
            throw CryptoError.convertToData
        }
        let encryptionKey = try Crypto.sharedInstance.deriveKey(keyData: try Seed.getBackupSeed(), context: contextData)
        try Keychain.sharedInstance.save(secretData: encryptionKey, id: KeyIdentifier.encryption.identifier(for: keychainService), service: keychainService, classification: .secret)
    }
    
    private func encryptionKey() throws -> Data {
        return try Keychain.sharedInstance.get(id: KeyIdentifier.encryption.identifier(for: keychainService), service: keychainService)
    }
    
    private func publicKey() throws -> String {
        let pubKey = try Keychain.sharedInstance.get(id: KeyIdentifier.pub.identifier(for: keychainService), service: keychainService)
        let base64PubKey = try Crypto.sharedInstance.convertToBase64(from: pubKey)
        return base64PubKey
    }
    
    private func privateKey() throws -> Data {
        let privKey = try Keychain.sharedInstance.get(id: KeyIdentifier.priv.identifier(for: keychainService), service: keychainService)
        return privKey
    }
    
    private func createSigningKeypair() throws -> String {
        let keyPair = try Crypto.sharedInstance.createSigningKeyPair(seed: try Seed.getBackupSeed())
        try Keychain.sharedInstance.save(secretData: keyPair.publicKey.data, id: KeyIdentifier.pub.identifier(for: keychainService), service: keychainService, classification: .restricted)
        try Keychain.sharedInstance.save(secretData: keyPair.secretKey.data, id: KeyIdentifier.priv.identifier(for: keychainService), service: keychainService, classification: .secret)
        
        let base64PubKey = try Crypto.sharedInstance.convertToBase64(from: keyPair.publicKey.data)
        return base64PubKey
    }
    
}
