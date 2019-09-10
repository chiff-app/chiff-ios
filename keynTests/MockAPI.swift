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

    init(pubKey: String? = nil, account: [String: String]? = nil, shouldFail: Bool = false) {
        if let pubKey = pubKey, let account = account {
            mockData[pubKey] = account
        }
        self.shouldFail = shouldFail
    }

    func signedRequest(endpoint: APIEndpoint, method: APIMethod, message: JSONObject?, pubKey: String?, privKey: Data, body: Data? = nil, completionHandler: @escaping (Result<JSONObject, Error>) -> Void) {
        if shouldFail {
            completionHandler(.failure(MockAPIError.fakeError))
        } else {
            switch endpoint {
            case .backup: completionHandler(backupCall(method: method, message: message, pubKey: pubKey, privKey: privKey, body: body))
            default: completionHandler(.failure(MockAPIError.notImplemented))
            }
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
            if mockData.isEmpty {
                mockData[pubKey] = ["ed98282a25e0ee58019d15523ad779bc27f2c84a73a3d43ae38acbeeede1988e":"ZhOIrj7miy4fkGUtLE8-hMCcc9QHpvMqfvwUvS5qhwTzG-2DDq6tHWO17tKDNnNzE3XL-0HxWkAK8kXz__M_OYQ24Yci2hyBdW1xxTx1TDErSRokfkIbrneo6HIoHWoY7tmEfg8kOq3OY8iX3LkFxDAwW01_R_MCxS5xMhQLm_f_4XTsTmWP5mVZgPK8fc0MEW7u7YfGxZHuvHsseadb4gKrIHk7_Xtemg4bjLaxqh1POza_O7rZP2Q9wBKOLPMBp7MMOF41QQrdN-5MGVDnP7wJ3rKjnSLkhuSRxxVOGYUDyo-qLksoJ_D-TkO2zk8lDgnBQa43HPG9cbqNMW59dtsj4jE6JWaEU8zcqPGx54E5nzJzGrkGT1b9Q6llG4g8qfL-N1Cy_wmwGMHLdJfi0pFGcPURtsgs8Jbq4TbWEPwDavKvNHDJRaDYT-3umgJKR4CyYeovhWAuQphOeW7Zan6AtFEFI8nJXthiR90UN6CGPdOywrZhSIpC2yhwMhDQeViCM2S6FV_IpnT7D7CbkdVJko6DBuEpr3F2kw-CMPre5GRXsdaqXyY5bhqOWL074UrT3Y-HX3Uz7Zsc_3mMBUiP0ClrVScEHbeZ5VgtIJ9G-I1AwiW3fbxTYNXA0wE1Pxy5uvOtBqZ73R8Ow7fZOYMPEazNYDU-4CpGGMc1bP11BchC6MHPIjVMgwsiO5bpuNMTiAynTL8T5EGFXkHjAh-a0phSfM2B46hgwlRbFebQOlMz0isuaf4HxnxuRvdSnbAOnUFTIKuwPKYxF15qTj6qS7cluuVEHYde7HNeV_Ey70Jgd06ECkk59EqtmBV0gO0Y6rSeHWsQvAIZwmUkkgYCH4NTmpi4c6KkTyefRINeFSi_5Gah8-MCM7OD_OC3sdCuFBQBi6gSMcDEZg_khySRrFBSk1aUA2z7pEl9N0CLOrxQt-_7nRWxgiBZ7t1pxZ0yyQ7bVUhNdrdBdmoaaw-SNvOatOWDy0OCFQJvdKKrahPUwaEmc_P9cAnb-dznfQJHS8UCMiNvIUmx7UHPA_NvKq6gn9_9gUN00g"]
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
