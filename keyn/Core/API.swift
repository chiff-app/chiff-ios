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

protocol API: URLSessionDelegate {

    var urlSession: URLSession! { get set }

    func signedRequest(endpoint: APIEndpoint, method: APIMethod, message: JSONObject?, pubKey: String?, privKey: Data, body: Data?, completionHandler: @escaping (Result<JSONObject, Error>) -> Void)

    func request(endpoint: APIEndpoint, path: String?, parameters: RequestParameters, method: APIMethod, signature: String?, body: Data?, completionHandler: @escaping (Result<JSONObject, Error>) -> Void)

    func send(_ request: URLRequest, completionHandler: @escaping (Result<JSONObject, Error>) -> Void)

    func createRequest(endpoint: APIEndpoint, path: String?, parameters: RequestParameters, signature: String?, method: APIMethod, body: Data?) throws -> URLRequest
}

extension API {
    
    func send(_ request: URLRequest, completionHandler: @escaping (Result<JSONObject, Error>) -> Void) {
        let task = urlSession.dataTask(with: request) { (result) in
            do {
                switch result {
                case .success(let response, let data):
                    if response.statusCode == 200 {
                        guard let data = data, !data.isEmpty else {
                            throw APIError.noData
                        }
                        let jsonData = try JSONSerialization.jsonObject(with: data, options: [])
                        guard let json = jsonData as? [String: Any] else {
                            throw APIError.jsonSerialization
                        }
                        completionHandler(.success(json))
                    } else {
                        throw APIError.statusCode(response.statusCode)
                    }
                case .failure(let error): throw error
                }
            } catch {
                print("API network error: \(error)")
                completionHandler(.failure(error))
            }
            
        }
        task.resume()
    }
}
