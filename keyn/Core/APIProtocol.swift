/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import Foundation

enum APIError: KeynError {
    case url
    case jsonSerialization
    case request(error: Error)
    case statusCode(Int)
    case noResponse
    case noData
    case response
    case wrongResponseType
    case pinninigError
}

enum APIEndpoint: String {
    case accounts = "accounts"
    case backup = "backup"
    case device = "device"
    case ppd = "ppd"
    case analytics = "analytics"
    case message = "message"
    case pairing = "message/pairing"
    case volatile = "message/volatile"
    case persistentAppToBrowser = "message/persistent/app-to-browser"
    case persistentBrowserToApp = "message/persistent/browser-to-app"
    case push = "message/push"
    case questionnaire = "questionnaire"
    case subscription = "subscription"
    case iosSubscription = "subscription/ios"

    // This construcs the endpoint for the subscription
    static func notificationSubscription(for pubkey: String) -> String {
        return "\(pubkey)/subscription"
    }

    // This construcs the endpoint for deleting all backup data
    static func deleteAll(for pubkey: String) -> String {
        return "\(pubkey)/all"
    }
}

enum APIMethod: String {
    case get = "GET"
    case put = "PUT"
    case post = "POST"
    case delete = "DELETE"
}

extension URLSession {
    func dataTask(with url: URLRequest, result: @escaping (Result<(HTTPURLResponse, Data?), Error>) -> Void) -> URLSessionDataTask {
        return dataTask(with: url) { (data, response, error) in
            if let error = error {
                return result(.failure(error))
            }
            guard let httpResponse = response as? HTTPURLResponse else {
                Logger.shared.error("API error. Wrong Response type")
                return result(.failure(APIError.wrongResponseType))
            }
            result(.success((httpResponse, data)))
        }
    }
}

typealias JSONObject = Dictionary<String, Any>
typealias RequestParameters = Dictionary<String, String>?

protocol APIProtocol {

    func signedRequest(endpoint: APIEndpoint, method: APIMethod, message: JSONObject?, pubKey: String?, privKey: Data, body: Data?, completionHandler: @escaping (Result<JSONObject, Error>) -> Void)

    func request(endpoint: APIEndpoint, path: String?, parameters: RequestParameters, method: APIMethod, signature: String?, body: Data?, completionHandler: @escaping (Result<JSONObject, Error>) -> Void)

}

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
            if let _ = mockData[pubKey] { // Check if the object exists so it updates, if not then it should fail
                mockData[pubKey] = message
                return .success(JSONObject())
            } else {
                return .failure(MockAPIError.noData)
            }
        }
    }
}
