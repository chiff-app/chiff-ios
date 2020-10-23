/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */

import UIKit
import PromiseKit
import DeviceCheck

struct NotificationManager {

    static let shared = NotificationManager()

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
            guard let endpoint = result["arn"] as? String else {
                Logger.shared.error("Could not find ARN in server respoonse")
                return
            }
            if Keychain.shared.has(id: KeyIdentifier.endpoint.identifier(for: .aws), service: .aws) {
                try Keychain.shared.update(id: KeyIdentifier.endpoint.identifier(for: .aws), service: .aws, secretData: endpoint.data)
            } else {
                try Keychain.shared.save(id: KeyIdentifier.endpoint.identifier(for: .aws), service: .aws, secretData: endpoint.data)
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
            API.shared.signedRequest(method: .delete, message: message, path: "users/\(try Seed.publicKey())/devices/\(id)", privKey: try Seed.privateKey(), body: nil, parameters: nil)
        }.done { _ in
            NotificationManager.shared.deleteKeys()
        }.log("Failed to delete ARN @ AWS.")
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
            return API.shared.signedRequest(method: .post, message: message, path: "users/\(try Seed.publicKey())/devices/\(id)", privKey: try Seed.privateKey(), body: nil, parameters: nil)
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
            API.shared.signedRequest(method: .put, message: message, path: "users/\(try Seed.publicKey())/devices/\(id)", privKey: try Seed.privateKey(), body: nil, parameters: nil)
        }
    }

}