//
//  NotificationManager.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import UIKit
import PromiseKit
import DeviceCheck
import ChiffCore

/// Handles registration of the device at the back-end
struct NotificationManager {

    static let shared = NotificationManager()

    /// Register this device at the back-end.
    /// - Parameter pushToken: The `pushToken` as provided by the system.
    func registerDevice(token pushToken: Data) {
        let token = pushToken.hexEncodedString()
        guard let id = UIDevice.current.identifierForVendor?.uuidString else {
            return
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

    /// Unregister this device at the back-end aand delete the keys.
    func unregisterDevice() -> Promise<Void> {
        guard let endpoint = Properties.endpoint, let id = UIDevice.current.identifierForVendor?.uuidString else {
            return .value(())
        }
        let message = [
            "endpoint": endpoint,
            "id": id
        ]
        return firstly {
            API.shared.signedRequest(path: "users/\(try Seed.publicKey())/devices/\(id)", method: .delete, privKey: try Seed.privateKey(), message: message)
        }.done { _ in
            NotificationManager.shared.deleteKeys()
        }.log("Failed to delete ARN @ AWS.")
    }

    /// Delete the keys from the Keychain.
    func deleteKeys() {
        Keychain.shared.deleteAll(service: .aws)
    }

    // MARK: - Private functions

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
            return API.shared.signedRequest(path: "users/\(try Seed.publicKey())/devices/\(id)", method: .post, privKey: try Seed.privateKey(), message: message)
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
            API.shared.signedRequest(path: "users/\(try Seed.publicKey())/devices/\(id)", method: .put, privKey: try Seed.privateKey(), message: message)
        }
    }

}
