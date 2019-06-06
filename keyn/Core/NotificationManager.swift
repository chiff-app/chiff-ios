/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */

import Foundation

struct NotificationManager {

    static let shared = NotificationManager()

    private enum MessageIdentifier {
        static let token = "token"
        static let endpoint = "endpoint"
        static let arn = "arn"
        static let os = "os"
    }


    private enum KeyIdentifier: String, Codable {
        case subscription = "subscription"
        case endpoint = "endpoint"

        func identifier(for keychainService: KeychainService) -> String {
            return "\(keychainService.rawValue).\(self.rawValue)"
        }
    }

    var endpoint: String? {
        guard let endpointData = try? Keychain.shared.get(id: KeyIdentifier.endpoint.identifier(for: .aws), service: .aws) else {
            return nil
        }
        return String(data: endpointData, encoding: .utf8)
    }

    var isSubscribed: Bool {
        return Keychain.shared.has(id: KeyIdentifier.subscription.identifier(for: .aws), service: .aws)
    }

    func snsRegistration(deviceToken: Data) {
        do {
            let token = deviceToken.hexEncodedString()
            if Keychain.shared.has(id: KeyIdentifier.endpoint.identifier(for: .aws), service: .aws) {
                // Get endpoint from Keychain
                try updateEndpoint(token: token, pubKey: BackupManager.shared.publicKey(), endpoint: endpoint)
            } else {
                // Create new endpoint if not found in storage
                try updateEndpoint(token: token, pubKey: BackupManager.shared.publicKey(), endpoint: nil)
            }
        } catch {
            Logger.shared.error("Error updating endpoint", error: error)
        }
    }

    func updateEndpoint(token: String, pubKey: String, endpoint: String?) throws {
        var message = [
            MessageIdentifier.token: token,
            MessageIdentifier.os: "ios"
        ]
        if let endpoint = endpoint {
            message[MessageIdentifier.endpoint] = endpoint
        }
        API.shared.signedRequest(endpoint: .device, method: .post, message: message, pubKey: try BackupManager.shared.publicKey(), privKey: try BackupManager.shared.privateKey()) { (dict, error) in
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
        do {
            API.shared.signedRequest(endpoint: .device, method: .delete, message: [MessageIdentifier.endpoint: endpoint], pubKey: try BackupManager.shared.publicKey(), privKey: try BackupManager.shared.privateKey()) { (dict, error) in
                if let error = error {
                    Logger.shared.error("Failed to delete ARN @ AWS.", error: error)
                }
            }
        } catch {
            Logger.shared.error("Failed to get key from Keychain.", error: error)
        }
    }

    func subscribe(topic: String, completion: ((_ error: Error?) -> Void)?) {
        guard let endpoint = endpoint else {
            Logger.shared.warning("Tried to subscribe without endpoint present")
            completion?(nil)
            return
        }
        let message = [
            "endpoint": endpoint,
            "topic": topic
        ]
        do {
            API.shared.signedRequest(endpoint: .device, method: .post, message: message, pubKey: APIEndpoint.subscription(for: try BackupManager.shared.publicKey()), privKey: try BackupManager.shared.privateKey()) { (dict, error) in
                do {
                    if let error = error {
                        throw error
                    } else if let subscriptionArn = dict?["arn"] as? String {
                        try Keychain.shared.save(id: KeyIdentifier.subscription.identifier(for: .aws), service: .aws, secretData: subscriptionArn.data)
                        completion?(nil)
                    }
                } catch {
                    Logger.shared.error("Failed to subscribe to topic ARN @ AWS.", error: error)
                    completion?(error)
                }
            }
        } catch {
            Logger.shared.error("Failed to get key from Keychain.", error: error)
            completion?(error)
        }
    }

    func unsubscribe(completion: @escaping (_ error: Error?) -> Void) {
        guard isSubscribed else {
            completion(nil)
            return
        }
        do {
            guard let subscription = String(data: try Keychain.shared.get(id: KeyIdentifier.subscription.identifier(for: .aws), service: .aws), encoding: .utf8) else {
                throw CodingError.stringDecoding
            }
            API.shared.signedRequest(endpoint: .device, method: .delete, message: ["arn": subscription], pubKey: APIEndpoint.subscription(for: try BackupManager.shared.publicKey()), privKey: try BackupManager.shared.privateKey()) { (dict, error) in
                do {
                    if let error = error {
                        throw error
                    } else {
                        try Keychain.shared.delete(id: KeyIdentifier.subscription.identifier(for: .aws), service: .aws)
                        completion(nil)
                    }
                } catch {
                    Logger.shared.error("Failed to unsubscribe to topic ARN @ AWS.", error: error)
                    completion(error)
                }
            }
        } catch {
            Logger.shared.error("Failed to get key from Keychain.", error: error)
            completion(error)
        }
    }

}
