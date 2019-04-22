/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import Foundation

struct BackupManager {

    private let CRYPTO_CONTEXT = "keynback"
    static let shared = BackupManager()
    
    var hasKeys: Bool {
        return Keychain.shared.has(id: KeyIdentifier.pub.identifier(for: .backup), service: .backup) &&
        Keychain.shared.has(id: KeyIdentifier.priv.identifier(for: .backup), service: .backup) &&
        Keychain.shared.has(id: KeyIdentifier.encryption.identifier(for: .backup), service: .backup)
    }

    var endpoint: String? {
        guard let endpointData = try? Keychain.shared.get(id: KeyIdentifier.endpoint.identifier(for: .aws), service: .aws) else {
            return nil
        }
        return String(data: endpointData, encoding: .utf8)
    }

    private enum KeyIdentifier: String, Codable {
        case priv = "priv"
        case pub = "pub"
        case encryption = "encryption"
        case endpoint = "endpoint"
        
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

    func initialize(completionHandler: @escaping (_ error: Error?) -> Void) {
        do {
            guard !hasKeys else {
                Logger.shared.warning("Tried to create backup keys while they already existed")
                return
            }
            try createEncryptionKey()
            let pubKey = try createSigningKeypair()

            apiRequest(endpoint: .backup, method: .put, pubKey: pubKey) { (_, error) in
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
    
    func backup(id: String, accountData: Data) throws {
        let ciphertext = try Crypto.shared.encryptSymmetric(accountData, secretKey: try encryptionKey())

        let message = [
            MessageIdentifier.id: id,
            MessageIdentifier.data: ciphertext.base64
        ]
        apiRequest(endpoint: .backup, method: .post, message: message) { (_, error) in
            if let error = error {
                Logger.shared.error("BackupManager cannot backup account data.", error: error)
            }
        }
    }
    
    func deleteAccount(accountId: String) throws {
        apiRequest(endpoint: .backup, method: .delete, message: [MessageIdentifier.id: accountId]) { (_, error) in
            if let error = error {
                Logger.shared.error("BackupManager cannot delete account.", error: error)
            }
        }
    }
    
    func getBackupData(completionHandler: @escaping () -> Void) throws {
        var pubKey: String

        if !Keychain.shared.has(id: KeyIdentifier.pub.identifier(for: .backup), service: .backup) {
            try createEncryptionKey()
            pubKey = try createSigningKeypair()
        } else {
            pubKey = try publicKey()
        }
        apiRequest(endpoint: .backup, method: .get, pubKey: pubKey) { (dict, error) in
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
                        Logger.shared.error("Could not restore account.", error: error)
                    }
                }
            }
            Logger.shared.analytics("Accunts restored", code: .accountsRestored, userInfo: ["accounts": dict.count])
            completionHandler()
        }
    }

    func snsRegistration(deviceToken: Data) {
        do {
            let token = deviceToken.hexEncodedString()
            if Keychain.shared.has(id: KeyIdentifier.endpoint.identifier(for: .aws), service: .aws) {
                // Get endpoint from Keychain
                try updateEndpoint(token: token, pubKey: publicKey(), endpoint: endpoint)
            } else {
                // Create new endpoint if not found in storage
                try updateEndpoint(token: token, pubKey: publicKey(), endpoint: nil)
            }
        } catch {
            Logger.shared.error("Error updating endpoint", error: error)
        }
    }

    func updateEndpoint(token: String, pubKey: String, endpoint: String?) throws {
        var message = [
            MessageIdentifier.token: token
        ]
        if let endpoint = endpoint {
            message[MessageIdentifier.endpoint] = endpoint
        }
        apiRequest(endpoint: .device, method: .post, message: message) { (dict, error) in
            do {
                if let error = error {
                    throw error
                }
                guard let dict = dict else {
                    throw CodingError.missingData
                }
                if let endpoint = dict["arn"] as? String {
                    if Keychain.shared.has(id: KeyIdentifier.endpoint.identifier(for: .aws), service: .aws) {
                        try Keychain.shared.update(id: KeyIdentifier.endpoint.identifier(for: .aws), service: .aws, secretData: endpoint.data)
                    } else {
                        try Keychain.shared.save(id: KeyIdentifier.endpoint.identifier(for: .aws), service: .aws, secretData: endpoint.data)
                    }
                }
            } catch {
                Logger.shared.error("AWS cannot get arn.", error: error)
                return
            }
        }
    }

    func deleteEndpoint() {
        guard let endpoint = endpoint else {
            Logger.shared.warning("Tried to delete endpoint without endpoint present")
            return
        }
        apiRequest(endpoint: .device, method: .delete, message: [MessageIdentifier.endpoint: endpoint]) { (dict, error) in
            if let error = error {
                Logger.shared.error("Failed to delete ARN @ AWS.", error: error)
            }
        }
    }
    
    func deleteAllKeys() {
        Keychain.shared.deleteAll(service: .aws)
        Keychain.shared.deleteAll(service: .backup)
    }

    // MARK: - Private


    private func signMessage(message: Data) throws -> String {
        let signature = try Crypto.shared.sign(message: message, privKey: try privateKey())
        let base64Signature = try Crypto.shared.convertToBase64(from: signature)

        return base64Signature
    }
    
    private func encryptionKey() throws -> Data {
        return try Keychain.shared.get(id: KeyIdentifier.encryption.identifier(for: .backup), service: .backup)
    }
    
    private func publicKey() throws -> String {
        let pubKey = try Keychain.shared.get(id: KeyIdentifier.pub.identifier(for: .backup), service: .backup)
        let base64PubKey = try Crypto.shared.convertToBase64(from: pubKey)
        return base64PubKey
    }
    
    private func privateKey() throws -> Data {
        return try Keychain.shared.get(id: KeyIdentifier.priv.identifier(for: .backup), service: .backup)
    }
    
    private func createSigningKeypair() throws -> String {
        let keyPair = try Crypto.shared.createSigningKeyPair(seed: try Seed.getBackupSeed())
        try Keychain.shared.save(id: KeyIdentifier.pub.identifier(for: .backup), service: .backup, secretData: keyPair.pubKey)
        try Keychain.shared.save(id: KeyIdentifier.priv.identifier(for: .backup), service: .backup, secretData: keyPair.privKey)
        let base64PubKey = try Crypto.shared.convertToBase64(from: keyPair.pubKey)
        return base64PubKey
    }
    
    private func createEncryptionKey() throws {
        let encryptionKey = try Crypto.shared.deriveKey(keyData: try Seed.getBackupSeed(), context: CRYPTO_CONTEXT)
        try Keychain.shared.save(id: KeyIdentifier.encryption.identifier(for: .backup), service: .backup, secretData: encryptionKey)
    }

    private func apiRequest(endpoint: APIEndpoint, method: APIMethod, message: [String: Any]? = nil, pubKey: String? = nil, completionHandler: @escaping (_ res: [String: Any]?, _ error: Error?) -> Void) {
        var message = message ?? [:]
        message["httpMethod"] = method.rawValue
        message["timestamp"] = String(Int(Date().timeIntervalSince1970))

        do {
            let privKey = try Keychain.shared.get(id: KeyIdentifier.priv.identifier(for: .backup), service: .backup)
            let jsonData = try JSONSerialization.data(withJSONObject: message, options: [])
            let signature = try Crypto.shared.sign(message: jsonData, privKey: privKey)

            let parameters = [
                "m": try Crypto.shared.convertToBase64(from: jsonData),
                "s": try Crypto.shared.convertToBase64(from: signature)
            ]

            API.shared.request(endpoint: endpoint, path: try pubKey ?? publicKey(), parameters: parameters, method: method, completionHandler: completionHandler)
        } catch {
            completionHandler(nil, error)
        }
    }

}
