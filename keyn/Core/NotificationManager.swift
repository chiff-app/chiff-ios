/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */

import UIKit

struct NotificationManager {

    static let shared = NotificationManager()

    private enum MessageIdentifier {
        static let token = "token"
        static let endpoint = "endpoint"
        static let arn = "arn"
        static let os = "os"
    }

    var isSubscribed: Bool {
        return Keychain.shared.has(id: KeyIdentifier.subscription.identifier(for: .aws), service: .aws)
    }

    func snsRegistration(deviceToken: Data) {
        do {
            let token = deviceToken.hexEncodedString()
            if Keychain.shared.has(id: KeyIdentifier.endpoint.identifier(for: .aws), service: .aws) {
                // Get endpoint from Keychain
                try updateEndpoint(token: token, pubKey: BackupManager.publicKey(), endpoint: Properties.endpoint)
            } else {
                // Create new endpoint if not found in storage
                try updateEndpoint(token: token, pubKey: BackupManager.publicKey(), endpoint: nil)
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
        API.shared.signedRequest(method: .post, message: message, path: "devices/\(try BackupManager.publicKey())", privKey: try BackupManager.privateKey(), body: nil) { result in

            do {
                if let endpoint = try result.get()["arn"] as? String {
                    if Keychain.shared.has(id: KeyIdentifier.endpoint.identifier(for: .aws), service: .aws) {
                        try Keychain.shared.update(id: KeyIdentifier.endpoint.identifier(for: .aws), service: .aws, secretData: endpoint.data)
                    } else {
                        try Keychain.shared.save(id: KeyIdentifier.endpoint.identifier(for: .aws), service: .aws, secretData: endpoint.data)
                    }
                    if Properties.infoNotifications == .notDecided && !NotificationManager.shared.isSubscribed {
                        self.subscribe(topic: Properties.notificationTopic) { result in
                            switch result {
                            case .success(_): Properties.infoNotifications = .yes
                            case .failure(_): Properties.infoNotifications = .no
                            }
                        }
                    }
                }
            } catch {
                Logger.shared.error("AWS cannot get arn.", error: error)
            }
        }
    }

    func deleteEndpoint() {
        guard let endpoint = Properties.endpoint else {
            return
        }
        
        do {
            API.shared.signedRequest(method: .delete, message: [MessageIdentifier.endpoint: endpoint], path: "devices/\(try BackupManager.publicKey())", privKey: try BackupManager.privateKey(), body: nil) { result in
                if case let .failure(error) = result {
                    Logger.shared.error("Failed to delete ARN @ AWS.", error: error)
                }
            }
        } catch {
            Logger.shared.error("Failed to get key from Keychain.", error: error)
        }
    }

    func subscribe(topic: String, completionHandler: ((Result<Void, Error>) -> Void)?) {
        guard let endpoint = Properties.endpoint else {
            Logger.shared.warning("Tried to subscribe without endpoint present")
            #warning("TODO: Should be considered as an error")
            completionHandler?(.success(()))
            return
        }
        let message = [
            "endpoint": endpoint,
            "topic": topic
        ]
        do {
            API.shared.signedRequest(method: .post, message: message, path: "news/\(try BackupManager.publicKey())", privKey: try BackupManager.privateKey(), body: nil) { result in
                do {
                    if let subscriptionArn = try result.get()["arn"] as? String {
                        let id = KeyIdentifier.subscription.identifier(for: .aws)
                        if Keychain.shared.has(id: id, service: .aws) {
                            try Keychain.shared.update(id: id, service: .aws, secretData: subscriptionArn.data)
                        } else {
                            try Keychain.shared.save(id: id, service: .aws, secretData: subscriptionArn.data)
                        }
                        completionHandler?(.success(()))
                    }
                } catch {
                    Logger.shared.error("Failed to subscribe to topic ARN @ AWS.", error: error)
                    completionHandler?(.failure(error))
                }
            }
        } catch {
            Logger.shared.error("Failed to get key from Keychain.", error: error)
            completionHandler?(.failure(error))
        }
    }

    func unsubscribe(completionHandler: @escaping (Result<Void, Error>) -> Void) {
        guard isSubscribed else {
            #warning("TODO: Should be considered as an error")
            completionHandler(.success(()))
            return
        }
        do {
            guard let subscription = String(data: try Keychain.shared.get(id: KeyIdentifier.subscription.identifier(for: .aws), service: .aws), encoding: .utf8) else {
                throw CodingError.stringDecoding
            }
            API.shared.signedRequest(method: .delete, message: ["arn": subscription], path: "news/\(try BackupManager.publicKey())", privKey: try BackupManager.privateKey(), body: nil) { result in
                do {
                    let _ = try result.get()
                    try Keychain.shared.delete(id: KeyIdentifier.subscription.identifier(for: .aws), service: .aws)
                    completionHandler(.success(()))
                } catch {
                    Logger.shared.error("Failed to unsubscribe to topic ARN @ AWS.", error: error)
                    completionHandler(.failure(error))
                }
            }
        } catch {
            Logger.shared.error("Failed to get key from Keychain.", error: error)
            completionHandler(.failure(error))
        }
    }

    func deleteKeys() {
        Keychain.shared.deleteAll(service: .aws)
    }

}
