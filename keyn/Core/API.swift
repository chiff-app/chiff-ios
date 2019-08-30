/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import Foundation
import TrustKit

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

class API: NSObject {
    
    static let shared = API()

    private var urlSession: URLSession! 

    override private init() {
        super.init()
        urlSession = URLSession(configuration: URLSessionConfiguration.ephemeral, delegate: self, delegateQueue: nil)
    }

    func signedRequest(endpoint: APIEndpoint, method: APIMethod, message: [String: Any]? = nil, pubKey: String?, privKey: Data, body: Data? = nil, completionHandler: @escaping (_ res: [String: Any]?, _ error: Error?) -> Void) {
        var message = message ?? [:]
        message["httpMethod"] = method.rawValue
        message["timestamp"] = String(Int(Date().timeIntervalSince1970))
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: message, options: [])
            let signature = (try Crypto.shared.signature(message: jsonData, privKey: privKey)).base64
            let parameters = [
                "m": try Crypto.shared.convertToBase64(from: jsonData),
                "s": "42" // Geen idee waarom dit er nog in moet
            ]
            request(endpoint: endpoint, path: pubKey, parameters: parameters, method: method, signature: signature, body: body, completionHandler: completionHandler)
        } catch {
            completionHandler(nil, error)
        }
    }

    func request(endpoint: APIEndpoint, path: String?, parameters: [String: String]?, method: APIMethod, signature: String? = nil, body: Data? = nil, completionHandler: @escaping (_ res: [String: Any]?, _ error: Error?) -> Void) {
        do {
            let request = try createRequest(endpoint: endpoint, path: path, parameters: parameters, signature: signature, method: method, body: body)
            send(request, completionHandler: completionHandler)
        } catch {
            completionHandler(nil, error)
        }
    }

    // MARK: - Private

    private func send(_ request: URLRequest, completionHandler: @escaping (_ res: [String: Any]?, _ error: Error?) -> Void) {
        let task = urlSession.dataTask(with: request) { data, response, error in
            if let error = error {
                completionHandler(nil, (error as NSError).code == -999 ? APIError.pinninigError : error)
                return
            }
            if let httpStatus = response as? HTTPURLResponse {
                do {
                    if httpStatus.statusCode == 200 {
                        guard let data = data, !data.isEmpty else {
                            throw APIError.noData
                        }
                        let jsonData = try JSONSerialization.jsonObject(with: data, options: [])
                        guard let json = jsonData as? [String: Any] else {
                            throw APIError.jsonSerialization
                        }
                        completionHandler(json, nil)
                    } else if httpStatus.statusCode == 404 {
                        completionHandler(nil, nil)
                    } else if let error = error {
                        throw APIError.request(error: error)
                    } else {
                        throw APIError.statusCode(httpStatus.statusCode)
                    }
                } catch {
                    print("API error: \(error)")
                    completionHandler(nil, error)
                }
            } else {
                Logger.shared.error("API error. Wrong Response type")
                completionHandler(nil, APIError.wrongResponseType)
            }
        }
        task.resume()
    }

    private func createRequest(endpoint: APIEndpoint, path: String?, parameters: [String: String]?, signature: String?, method: APIMethod, body: Data?) throws -> URLRequest {
        var components = URLComponents()
        components.scheme = "https"
        components.host = Properties.keynApi
        components.path = "/\(Properties.environment.path)/\(endpoint.rawValue)"

        if let path = path {
            components.path += "/\(path)"
        }
        if let parameters = parameters {
            var queryItems = [URLQueryItem]()
            for (key, value) in parameters {
                let item = URLQueryItem(name: key, value: value)
                queryItems.append(item)
            }
            components.queryItems = queryItems
        }

        guard let url = components.url else {
            throw APIError.url
        }
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        if let signature = signature {
            request.setValue(signature, forHTTPHeaderField: "keyn-signature")
        }
        if let body = body {
            request.httpBody = body
        }
        return request
    }
}

extension API: URLSessionDelegate {

    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        let validator = TrustKit.sharedInstance().pinningValidator
        if !(validator.handle(challenge, completionHandler: completionHandler)) {
            completionHandler(URLSession.AuthChallengeDisposition.performDefaultHandling, nil)
        }
    }

}
