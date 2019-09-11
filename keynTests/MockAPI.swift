//
//  MockAPI.swift
//  keynTests
//
//  Created by Bas Doorn on 05/09/2019.
//  Copyright © 2019 keyn. All rights reserved.
//

import Foundation
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

    func signedRequest(endpoint: APIEndpoint, method: APIMethod, message: JSONObject?, pubKey: String?, privKey: Data, body: Data? = nil, completionHandler: @escaping (Result<JSONObject, Error>) -> Void) {
        if shouldFail {
            completionHandler(.failure(MockAPIError.fakeError))
        } else {
            switch endpoint {
            case .backup: completionHandler(backupCallSigned(method: method, message: message, pubKey: pubKey, privKey: privKey, body: body))
            case .pairing: completionHandler(pairingCallSigned(method: method, message: message, pubKey: pubKey, privKey: privKey, body: body))
            case .volatile: completionHandler(volatileCallSigned())
            case .persistentBrowserToApp: completionHandler(persistentBrowserToAppSignedCall())
            default: completionHandler(.failure(MockAPIError.notImplemented))
            }
        }
    }

    func request(endpoint: APIEndpoint, path: String?, parameters: RequestParameters, method: APIMethod, signature: String?, body: Data? = nil, completionHandler: @escaping (Result<JSONObject, Error>) -> Void) {
        if shouldFail {
            completionHandler(.failure(MockAPIError.fakeError))
        } else {
            switch endpoint {
            case .message: completionHandler(messageCall(path: path, parameters: parameters, method: method, signature: signature, body: body))
            case .ppd: completionHandler(ppdCall(id: path))
            case .questionnaire: completionHandler(questionnaire(method: method))
            default: completionHandler(.failure(MockAPIError.notImplemented))
            }
        }
    }
    
    private func questionnaire(method: APIMethod) -> Result<JSONObject, Error> {
        switch method {
        case .post:
            return .success(JSONObject())
        case .get:
            if let data = customData {
                return .success(["nothing": data])
            } else {
                if let path = Bundle(for: type(of: self)).path(forResource: "questionnaire", ofType: "json") {
                    do {
                        let fileUrl = URL(fileURLWithPath: path)
                        let data = try Data(contentsOf: fileUrl, options: .mappedIfSafe)
                        let jsonData = try JSONSerialization.jsonObject(with: data) as! JSONObject
                        return .success(["questionnaires": [jsonData]])
                    } catch {
                        fatalError(error.localizedDescription)
                    }
                } else {
                    return .success(JSONObject())
                }
            }
        default:
            fatalError("This method is not availble on the API")
        }
    }
    
    private func ppdCall(id: String?) -> Result<JSONObject, Error> {
        if id == "1" {
            if let path = Bundle(for: type(of: self)).path(forResource: "samplePPD", ofType: "json") {
                do {
                    let fileUrl = URL(fileURLWithPath: path)
                    let data = try Data(contentsOf: fileUrl, options: .mappedIfSafe)
                    return .success(try JSONSerialization.jsonObject(with: data) as! JSONObject)
                } catch {
                    fatalError(error.localizedDescription)
                }
            } else {
                return .success(JSONObject())
            }
        } else if id == "2" {
            return .success(["ppds":[["wrong":"data"]]])
        } else {
            return .success(["nothing":[]])
        }
    }

    private func persistentBrowserToAppSignedCall() -> Result<JSONObject, Error> {
        if let data = customData as? [[String: String]] {
            return .success([
                "messages": data
                ])
        }
        return .success(JSONObject())
    }
    
    private func volatileCallSigned() -> Result<JSONObject, Error> {
        return .success(JSONObject())
    }
    
    private func pairingCallSigned(method: APIMethod, message: JSONObject?, pubKey: String?, privKey: Data, body: Data?) -> Result<JSONObject, Error> {
        return .success(JSONObject())
    }
    
    private func messageCall(path: String?, parameters: RequestParameters, method: APIMethod, signature: String?, body: Data? = nil) -> Result<JSONObject, Error> {
        return .success(JSONObject())
    }

    private func backupCallSigned(method: APIMethod, message: JSONObject?, pubKey: String?, privKey: Data, body: Data?) -> Result<JSONObject, Error> {
        guard let pubKey = pubKey else {
            return .failure(MockAPIError.noPublicKey)
        }
        switch method {
        case .get:
            if mockData.isEmpty {
                mockData[pubKey] = [TestHelper.userID:TestHelper.userData]
            }
            guard let data = mockData[pubKey] else {
                return .failure(MockAPIError.noData)
            }
            return .success(data)
        case .delete:
            if let message = message, let id = message["id"] as? String {
                if mockData[pubKey]?.removeValue(forKey: id) != nil {
                    return .success(JSONObject())
                } else {
                    return .failure(MockAPIError.badPublicKey)
                }
            } else if pubKey.contains("/all") {
                let newPubKey = String(pubKey[pubKey.startIndex..<pubKey.index(pubKey.endIndex, offsetBy: -4)])
                if mockData.removeValue(forKey: String(newPubKey)) != nil {
                    return .success(JSONObject())
                } else {
                    return .failure(MockAPIError.badPublicKey)
                }
            }
            return .success(JSONObject())
        case .post:
            guard let message = message, let id = message["id"] as? String, let recoverData = message["data"] as? String else {
                return .failure(MockAPIError.noData)
            }
            mockData[pubKey] = [id: recoverData]
            return .success(JSONObject())
        case .put:
            guard let message = message, let id = message["userId"] as? String else {
                return .failure(MockAPIError.noData)
            }
            mockData[pubKey] = [id: JSONObject()]
            return .success(JSONObject())
        }
    }
}
