//
//  MockAPI.swift
//  keynTests
//
//  Created by Bas Doorn on 05/09/2019.
//  Copyright © 2019 keyn. All rights reserved.
//

import Foundation
import PromiseKit
@testable import keyn

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

    func signedRequest(method: APIMethod, message: JSONObject?, path: String, privKey: Data, body: Data? = nil) -> Promise<JSONObject> {
        if shouldFail {
            return Promise(error: MockAPIError.fakeError)
        } else {
            let components = path.split(separator: "/")
            if components[0] == "users" {
                if components.count > 2 {
                    switch components[2] {
                    case "accounts": return userBackupCallSigned(method: method, message: message, pubKey: String(components[1]), privKey: privKey, body: body)
                    case "sessions": return .value(JSONObject()) // Not implemented yet
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

    func request(path: String, parameters: RequestParameters, method: APIMethod, signature: String?, body: Data? = nil) -> Promise<JSONObject> {
        if shouldFail {
            return Promise(error: MockAPIError.fakeError)
        } else {
            let components = path.split(separator: "/")
            switch components[0] {
            case "sessions": return messageCall(path: path, parameters: parameters, method: method, signature: signature, body: body)
            case "ppd": return ppdCall(id: String(components[1]))
            case "questionnaires": return questionnaire(method: method)
            default: return Promise(error: MockAPIError.notImplemented)
            }
        }
    }
    
    private func questionnaire(method: APIMethod) -> Promise<JSONObject> {
        switch method {
        case .post:
            return .value(JSONObject())
        case .get:
            if let data = customData {
                return .value(["nothing": data])
            } else {
                if let path = Bundle(for: type(of: self)).path(forResource: "questionnaire", ofType: "json") {
                    do {
                        let fileUrl = URL(fileURLWithPath: path)
                        let data = try Data(contentsOf: fileUrl, options: .mappedIfSafe)
                        let jsonData = try JSONSerialization.jsonObject(with: data) as! JSONObject
                        return .value(["questionnaires": [jsonData]])
                    } catch {
                        fatalError(error.localizedDescription)
                    }
                } else {
                    return .value(JSONObject())
                }
            }
        default:
            fatalError("This method is not availble on the API")
        }
    }
    
    private func ppdCall(id: String?) -> Promise<JSONObject> {
        if id == "1" {
            if let path = Bundle(for: type(of: self)).path(forResource: "samplePPD", ofType: "json") {
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
        } else if id == "2" {
            return .value(["ppds":[["wrong":"data"]]])
        } else {
            return .value(["nothing":[]])
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
    
    private func messageCall(path: String?, parameters: RequestParameters, method: APIMethod, signature: String?, body: Data? = nil) -> Promise<JSONObject> {
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
