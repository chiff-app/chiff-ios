/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import Foundation
import TrustKit

class APIKeyn: NSObject, API {
    
    var urlSession: URLSession!
    static let shared = APIKeyn()
    
    override init() {
        super.init()
        urlSession = URLSession(configuration: URLSessionConfiguration.ephemeral, delegate: self, delegateQueue: nil)
    }
    
    func signedRequest(endpoint: APIEndpoint, method: APIMethod, message: JSONObject? = nil, pubKey: String?, privKey: Data, body: Data? = nil, completionHandler: @escaping (Result<JSONObject, Error>) -> Void) {
        var message = message ?? [:]
        message["httpMethod"] = method.rawValue
        message["timestamp"] = String(Int(Date().timeIntervalSince1970))
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: message, options: [])
            let signature = (try Crypto.shared.signature(message: jsonData, privKey: privKey)).base64
            let parameters = [
                "m": try Crypto.shared.convertToBase64(from: jsonData),
                "s": "42"
            ]
            request(endpoint: endpoint, path: pubKey, parameters: parameters, method: method, signature: signature, body: body, completionHandler: completionHandler)
        } catch {
            completionHandler(.failure(error))
        }
    }
    
    func request(endpoint: APIEndpoint, path: String?, parameters: RequestParameters, method: APIMethod, signature: String? = nil, body: Data? = nil, completionHandler: @escaping (Result<JSONObject, Error>) -> Void) {
        do {
            let request = try createRequest(endpoint: endpoint, path: path, parameters: parameters, signature: signature, method: method, body: body)
            send(request, completionHandler: completionHandler)
        } catch {
            completionHandler(.failure(error))
        }
    }
    
    func createRequest(endpoint: APIEndpoint, path: String?, parameters: RequestParameters, signature: String?, method: APIMethod, body: Data?) throws -> URLRequest {
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
    
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        let validator = TrustKit.sharedInstance().pinningValidator
        if !(validator.handle(challenge, completionHandler: completionHandler)) {
            completionHandler(URLSession.AuthChallengeDisposition.performDefaultHandling, nil)
        }
    }
}
