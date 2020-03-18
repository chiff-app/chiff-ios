/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */

import UIKit
import PromiseKit

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
        firstly {
            API.shared.signedRequest(method: .post, message: message, path: "devices/\(try BackupManager.publicKey())", privKey: try BackupManager.privateKey(), body: nil)
        }.done { result in
            if let endpoint = result["arn"] as? String {
                if Keychain.shared.has(id: KeyIdentifier.endpoint.identifier(for: .aws), service: .aws) {
                    try Keychain.shared.update(id: KeyIdentifier.endpoint.identifier(for: .aws), service: .aws, secretData: endpoint.data)
                } else {
                    try Keychain.shared.save(id: KeyIdentifier.endpoint.identifier(for: .aws), service: .aws, secretData: endpoint.data)
                }
                if Properties.infoNotifications == .notDecided && !NotificationManager.shared.isSubscribed {
                    firstly {
                        self.subscribe()
                    }.done { result in
                        Properties.infoNotifications = result ? .yes : .no
                    }
                }
            }
        }.catchLog("AWS cannot get arn.")
    }

    func deleteEndpoint() {
        guard let endpoint = Properties.endpoint else {
            return
        }
        firstly {
            API.shared.signedRequest(method: .delete, message: [MessageIdentifier.endpoint: endpoint], path: "devices/\(try BackupManager.publicKey())", privKey: try BackupManager.privateKey(), body: nil)
        }.catchLog("Failed to delete ARN @ AWS.")
    }

    func subscribe() -> Guarantee<Bool> {
        guard let endpoint = Properties.endpoint else {
            Logger.shared.warning("Tried to subscribe without endpoint present")
            return .value(false)
        }
        let message = [
            "endpoint": endpoint
        ]
        return firstly {
            API.shared.signedRequest(method: .post, message: message, path: "news/\(try BackupManager.publicKey())", privKey: try BackupManager.privateKey(), body: nil)
        }.map { result in
            if let subscriptionArn = result["arn"] as? String {
                let id = KeyIdentifier.subscription.identifier(for: .aws)
                if Keychain.shared.has(id: id, service: .aws) {
                    try Keychain.shared.update(id: id, service: .aws, secretData: subscriptionArn.data)
                } else {
                    try Keychain.shared.save(id: id, service: .aws, secretData: subscriptionArn.data)
                }
                return true
            } else {
                return false
            }
        }.recover { error in
            Logger.shared.error("Failed to get key from Keychain.", error: error)
            return .value(false)
        }
    }

    func unsubscribe() -> Promise<Void> {
        guard isSubscribed else {
            #warning("TODO: Should be considered as an error?")
            return .value(())
        }
        do {
            guard let data = try Keychain.shared.get(id: KeyIdentifier.subscription.identifier(for: .aws), service: .aws), let subscription = String(data: data, encoding: .utf8) else {
                throw CodingError.stringDecoding
            }
            return firstly {
                API.shared.signedRequest(method: .delete, message: ["arn": subscription], path: "news/\(try BackupManager.publicKey())", privKey: try BackupManager.privateKey(), body: nil)
            }.map { result in
                try Keychain.shared.delete(id: KeyIdentifier.subscription.identifier(for: .aws), service: .aws)
                return
            }.log("Failed to unsubscribe to topic ARN @ AWS.")
        } catch {
            Logger.shared.error("Failed to get key from Keychain.", error: error)
            return Promise(error: error)
        }
    }

    func deleteKeys() {
        Keychain.shared.deleteAll(service: .aws)
    }

}
