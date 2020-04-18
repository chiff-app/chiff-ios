/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */

import UIKit
import PromiseKit
import DeviceCheck

struct NotificationManager {

    static let shared = NotificationManager()

    var isSubscribed: Bool {
        return Keychain.shared.has(id: KeyIdentifier.subscription.identifier(for: .aws), service: .aws)
    }

    func registerDevice(token pushToken: Data) {
        let token = pushToken.hexEncodedString()
        guard let id = UIDevice.current.identifierForVendor?.uuidString else {
            return // TODO: How to handle this?
        }
        firstly { () -> Promise<JSONObject> in
            if let endpoint = Properties.endpoint {
                return updateEndpoint(pushToken: token, id: id, endpoint: endpoint)
            } else {
                return createEndpoint(pushToken: token, id: id)
            }
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

    func deleteEndpoint() -> Promise<Void> {
        guard let endpoint = Properties.endpoint, let id = UIDevice.current.identifierForVendor?.uuidString else {
            return .value(())
        }
        let message = [
            "endpoint": endpoint,
            "id": id
        ]
        return firstly {
            API.shared.signedRequest(method: .delete, message: message, path: "users/\(try Seed.publicKey())/devices/\(id)", privKey: try Seed.privateKey(), body: nil)
        }.done { _ in
            NotificationManager.shared.deleteKeys()
        }.log("Failed to delete ARN @ AWS.")
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
            API.shared.signedRequest(method: .post, message: message, path: "news/\(try Seed.publicKey())", privKey: try Seed.privateKey(), body: nil)
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
                API.shared.signedRequest(method: .delete, message: ["arn": subscription], path: "news/\(try Seed.publicKey())", privKey: try Seed.privateKey(), body: nil)
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

    private func createEndpoint(pushToken: String, id: String) -> Promise<JSONObject> {
        return Promise<String?> { seal in
            DCDevice.current.generateToken { (data, error) in
                if let error = error {
                    Logger.shared.warning("Error retrieving device token.", error: error)
                    seal.fulfill(nil)
                } else {
                    seal.fulfill(data?.base64EncodedString())
                }
            }
        }.then { deviceToken -> Promise<JSONObject> in
            var message = [
                "pushToken": pushToken,
                "os": "ios",
                "id": id
            ]
            if let deviceToken = deviceToken {
                message["deviceToken"] = deviceToken
            }
            return API.shared.signedRequest(method: .post, message: message, path: "users/\(try Seed.publicKey())/devices/\(id)", privKey: try Seed.privateKey(), body: nil)
        }
    }

    private func updateEndpoint(pushToken: String, id: String, endpoint: String) -> Promise<JSONObject> {
        let message = [
            "pushToken": pushToken,
            "os": "ios",
            "endpoint": endpoint,
            "id": id
        ]
        return firstly {
            API.shared.signedRequest(method: .put, message: message, path: "users/\(try Seed.publicKey())/devices/\(id)", privKey: try Seed.privateKey(), body: nil)
        }
    }


}
