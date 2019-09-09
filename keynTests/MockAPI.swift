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
}

// For example
class MockAPI: APIProtocol {
    var mockData = [String: JSONObject]()

    init(pubKey: String? = nil, account: [String: String]? = nil) {
        if let pubKey = pubKey, let account = account {
            mockData[pubKey] = account
        }
    }

    func signedRequest(endpoint: APIEndpoint, method: APIMethod, message: JSONObject?, pubKey: String?, privKey: Data, body: Data? = nil, completionHandler: @escaping (Result<JSONObject, Error>) -> Void) {
        switch endpoint {
        case .backup: completionHandler(backupCall(method: method, message: message, pubKey: pubKey, privKey: privKey, body: body))
        default: completionHandler(.failure(MockAPIError.notImplemented))
        }
    }

    func request(endpoint: APIEndpoint, path: String?, parameters: RequestParameters, method: APIMethod, signature: String?, body: Data? = nil, completionHandler: @escaping (Result<JSONObject, Error>) -> Void) {
        // TODO
    }

    private func backupCall(method: APIMethod, message: JSONObject?, pubKey: String?, privKey: Data, body: Data?) -> Result<JSONObject, Error> {
        guard let pubKey = pubKey else {
            return .failure(MockAPIError.noPublicKey)
        }
        switch method {
        case .get:
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
