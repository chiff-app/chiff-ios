//
//  MockAPI.swift
//  ChiffCoreTests
//
//  Copyright: see LICENSE.md
//

import Foundation
import PromiseKit
@testable import ChiffCore

enum MockAPIError: Error {
    case notImplemented
    case noData
    case noPublicKey
    case badPublicKey
    case fakeError
}

// For example
class MockAPI: APIProtocol {
    var mockData = [String: JSONObject]()
    var shouldFail: Bool
    var customData: Any?

    init(pubKey: String? = nil, account: [String: String]? = nil, data: Any? = nil, shouldFail: Bool = false) {
        if let pubKey = pubKey, let account = account {
            mockData[pubKey] = account
        }
        self.shouldFail = shouldFail
        customData = data
    }

    func signedRequest(path: String, method: APIMethod, privKey: Data, message: JSONObject? = nil, body: Data? = nil, parameters: [String : String]? = nil) -> Promise<JSONObject> {
        if shouldFail {
            return Promise(error: MockAPIError.fakeError)
        } else {
            let components = path.split(separator: "/")
            if components[0] == "users" {
                if components.count > 2 {
                    switch components[2] {
                    case "accounts": return userBackupCallSigned(method: method, message: message, pubKey: String(components[1]), privKey: privKey, body: body)
                    case "sessions": return .value(JSONObject()) // Not implemented yet
                    case "sshkeys": return .value(JSONObject()) // Not implemented yet
                    default: return Promise(error: MockAPIError.notImplemented)
                    }
                } else {
                    return userBackupCallSigned(method: method, message: message, pubKey: String(components[1]), privKey: privKey, body: body)
                }
            } else if components[0] == "sessions" {
                if components.count > 2 {
                    switch components[2] {
                    case "pairing":
                        return pairingCallSigned(method: method, message: message, pubKey: String(components[1]), privKey: privKey, body: body)
                    case "volatile":
                        return volatileCallSigned()
                    case "browser-to-app":
                        return persistentBrowserToAppSignedCall()
                    case "app-to-browser":
                        return .value(JSONObject())
                    default:
                        return Promise(error: MockAPIError.notImplemented)
                    }
                } else {
                    return pairingCallSigned(method: method, message: message, pubKey: String(components[1]), privKey: privKey, body: body)
                }
            }
        }
        return Promise(error: MockAPIError.notImplemented)
    }

    func request(path: String, method: APIMethod, signature: String? = nil, body: Data? = nil, parameters: [String:String]? = nil) -> Promise<JSONObject> {
        if shouldFail {
            return Promise(error: MockAPIError.fakeError)
        } else {
            let components = path.split(separator: "/")
            switch components[0] {
            case "sessions": return messageCall(path: path, parameters: parameters, method: method, signature: signature, body: body)
            case "ppd": return ppdCall(id: String(components[1]))
            default: return Promise(error: MockAPIError.notImplemented)
            }
        }
    }

    func request<T>(path: String,  method: APIMethod, signature: String? = nil, body: Data? = nil, parameters: [String:String]? = nil) -> Promise<T> {
        return Promise(error: MockAPIError.notImplemented)
    }

    func signedRequest<T>(path: String, method: APIMethod, privKey: Data, message: JSONObject? = nil, body: Data? = nil, parameters: [String : String]? = nil) -> Promise<T> {
        return Promise(error: MockAPIError.notImplemented)
    }
    
    private func ppdCall(id: String?) -> Promise<JSONObject> {
        switch id {
        // TODO: SHA256 hashes should be used here.
        case "465359316cf124ca28f33cfb920fdacba6506ae2329dfd18669b3c6a3f52fadc":
            if let path = Bundle.module.path(forResource: "samplePPD", ofType: "json") {
                do {
                    let fileUrl = URL(fileURLWithPath: path)
                    let data = try Data(contentsOf: fileUrl, options: .mappedIfSafe)
                    return .value(try JSONSerialization.jsonObject(with: data) as! JSONObject)
                } catch {
                    fatalError(error.localizedDescription)
                }
            } else {
                return .value(JSONObject())
            }
        case "2":
            return .value(["ppds":[["wrong":"data"]]])
        case "3":
            return .value(["nothing":[]])
        case "3ce8c236a3bd3307e737a8aa14b8a520f37b2e3386555c9a269141332f4c746e":
            if let path = Bundle.module.path(forResource: "sampleRedirectPPD", ofType: "json") {
                do {
                    let fileUrl = URL(fileURLWithPath: path)
                    let data = try Data(contentsOf: fileUrl, options: .mappedIfSafe)
                    return .value(try JSONSerialization.jsonObject(with: data) as! JSONObject)
                } catch {
                    fatalError(error.localizedDescription)
                }
            } else {
                return .value(JSONObject())
            }
        default:
            return Promise(error: MockAPIError.notImplemented)
        }
    }

    private func persistentBrowserToAppSignedCall() -> Promise<JSONObject> {
        if let data = customData as? [[String: String]] {
            return .value([
                "messages": data
                ])
        }
        return .value(JSONObject())
    }
    
    private func volatileCallSigned() -> Promise<JSONObject> {
        return .value(JSONObject())
    }
    
    private func pairingCallSigned(method: APIMethod, message: JSONObject?, pubKey: String?, privKey: Data, body: Data?) -> Promise<JSONObject> {
        return .value(JSONObject())
    }
    
    private func messageCall(path: String?, parameters: [String:String]?, method: APIMethod, signature: String?, body: Data? = nil) -> Promise<JSONObject> {
        return .value(JSONObject())
    }

    private func userBackupCallSigned(method: APIMethod, message: JSONObject?, pubKey: String?, privKey: Data, body: Data?) -> Promise<JSONObject> {
        guard let pubKey = pubKey else {
            return Promise(error: MockAPIError.noPublicKey)
        }
        switch method {
        case .get:
            if mockData.isEmpty {
                mockData[pubKey] = [TestHelper.userID:TestHelper.userData]
            }
            guard let data = mockData[pubKey] else {
                return Promise(error: MockAPIError.noData)
            }
            return .value(data)
        case .delete:
            if let message = message, let id = message["id"] as? String {
                if mockData[pubKey]?.removeValue(forKey: id) != nil {
                    return .value(JSONObject())
                } else {
                    return Promise(error: MockAPIError.badPublicKey)
                }
            } else if pubKey.contains("/all") {
                let newPubKey = String(pubKey[pubKey.startIndex..<pubKey.index(pubKey.endIndex, offsetBy: -4)])
                if mockData.removeValue(forKey: String(newPubKey)) != nil {
                    return .value(JSONObject())
                } else {
                    return Promise(error: MockAPIError.badPublicKey)
                }
            }
            return .value(JSONObject())
        case .put:
            guard let message = message, let id = message["id"] as? String, let recoverData = message["data"] as? String else {
                return Promise(error: MockAPIError.noData)
            }
            mockData[pubKey] = [id: recoverData]
            return .value(JSONObject())
        case .post:
            guard let message = message, let id = message["userId"] as? String else {
                return Promise(error: MockAPIError.noData)
            }
            mockData[pubKey] = [id: JSONObject()]
            return .value(JSONObject())
        case .patch:
            return Promise(error: MockAPIError.notImplemented)
        }
    }
}
