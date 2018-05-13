//
//  BackupManager.swift
//  keyn
//
//  Created by bas on 22/04/2018.
//  Copyright © 2018 keyn. All rights reserved.
//

import Foundation

struct BackupManager {
    
    private let keychainService = "io.keyn.backup"
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
        
        let backupData = [
            "type": "createBackupData",
            "timestamp": String(Int(Date().timeIntervalSince1970)),
            "identityId": AWS.sharedInstance.getIdentityId()
        ]
        let jsonData = try JSONSerialization.data(withJSONObject: backupData, options: .prettyPrinted)
        let signedMessage = try Crypto.sharedInstance.sign(message: jsonData, privKey: try privateKey())
        
        let base64EncodedMessage = try Crypto.sharedInstance.convertToBase64(from: signedMessage)
        AWS.sharedInstance.createBackupData(pubKey: pubKey, signedMessage: base64EncodedMessage)
    }
    
    func backup(id: String, accountData: Data) throws {
        // TODO: Also sign account ID + add timestamp.
        let ciphertext = try Crypto.sharedInstance.encryptSymmetric(accountData, secretKey: try encryptionKey())
        let backupData = [
            "data": try Crypto.sharedInstance.convertToBase64(from: ciphertext),
            "type": "setBackupData",
            "accountId": id,
            "timestamp": String(Int(Date().timeIntervalSince1970)),
            "identityId": AWS.sharedInstance.getIdentityId()
        ]
        let jsonData = try JSONSerialization.data(withJSONObject: backupData, options: .prettyPrinted)
        let signedMessage = try Crypto.sharedInstance.sign(message: jsonData, privKey: try privateKey())
        let base64EncodedMessage = try Crypto.sharedInstance.convertToBase64(from: signedMessage)
        AWS.sharedInstance.backupAccount(pubKey: try publicKey(), message: base64EncodedMessage)
    }
    
    private func createEncryptionKey() throws {
        guard let contextData = "backup".data(using: .utf8) else {
            throw CryptoError.convertToData
        }
        let encryptionKey = try Crypto.sharedInstance.deriveKey(keyData: try Seed.getBackupSeed(), context: contextData)
        try Keychain.sharedInstance.save(secretData: encryptionKey, id: KeyIdentifier.encryption.identifier(for: keychainService), service: keychainService)
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
        let keyPair = try Crypto.sharedInstance.createBackupKeyPair(seed: try Seed.getBackupSeed())
        try Keychain.sharedInstance.save(secretData: keyPair.publicKey, id: KeyIdentifier.pub.identifier(for: keychainService), service: keychainService, restricted: false)
        try Keychain.sharedInstance.save(secretData: keyPair.secretKey, id: KeyIdentifier.priv.identifier(for: keychainService), service: keychainService, restricted: true)
        
        let base64PubKey = try Crypto.sharedInstance.convertToBase64(from: keyPair.publicKey)
        return base64PubKey
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
        let signedMessage = try Crypto.sharedInstance.sign(message: message, privKey: try privateKey())
        
        let base64Message = try Crypto.sharedInstance.convertToBase64(from: signedMessage)
        return base64Message
    }
    
    func deleteAccount(accountId: String) throws {
        let data = [
            "accountId": accountId,
            "type": "deleteAccount",
            "timestamp": String(Int(Date().timeIntervalSince1970)),
            "identityId": AWS.sharedInstance.getIdentityId()
        ]
        let jsonData = try JSONSerialization.data(withJSONObject: data, options: .prettyPrinted)
        let message = try signMessage(message: jsonData)
        AWS.sharedInstance.deleteAccountBackupData(pubKey: try publicKey(), message: message)
    }
    
    func getBackupData(completionHandler: @escaping () -> Void) throws {
        var pubKey: String
        if !Keychain.sharedInstance.has(id: KeyIdentifier.pub.identifier(for: keychainService), service: keychainService) {
            try createEncryptionKey()
            pubKey = try createSigningKeypair()
        } else {
            pubKey = try publicKey()
        }
        
        let data = [
            "type": "getBackupData",
            "timestamp": String(Int(Date().timeIntervalSince1970)),
            "identityId": AWS.sharedInstance.getIdentityId()
        ]
        let jsonData = try JSONSerialization.data(withJSONObject: data, options: .prettyPrinted)
        let signedMessage = try signMessage(message: jsonData)

        AWS.sharedInstance.getBackupData(pubKey: pubKey, message: signedMessage) { (dict) in
            for (id, data) in dict {
                if let base64Data = data as? String {
                    let ciphertext = try! Crypto.sharedInstance.convertFromBase64(from: base64Data)
                    let accountData = try! Crypto.sharedInstance.decryptSymmetric(ciphertext, secretKey: try! self.encryptionKey())
                    try! Account.save(accountData: accountData, id: id)
                }
            }
            completionHandler()
        }
    }
    
    func deleteAllKeys() {
        Keychain.sharedInstance.deleteAll(service: keychainService)
    }
    
}
