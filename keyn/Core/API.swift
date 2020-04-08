/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import Foundation
import TrustKit
import PromiseKit

class API: NSObject, APIProtocol {

    private var urlSession: URLSession!
    static var shared: APIProtocol = API()
    
    override init() {
        super.init()
        urlSession = URLSession(configuration: URLSessionConfiguration.ephemeral, delegate: self, delegateQueue: nil)
    }
    
    func signedRequest(method: APIMethod, message: JSONObject? = nil, path: String, privKey: Data, body: Data? = nil) -> Promise<JSONObject> {
        var message = message ?? [:]
        message["httpMethod"] = method.rawValue
        message["timestamp"] = String(Date.now)
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: message, options: [])
            let signature = (try Crypto.shared.signature(message: jsonData, privKey: privKey)).base64
            let parameters = [
                "m": try Crypto.shared.convertToBase64(from: jsonData)
            ]
            return request(path: path, parameters: parameters, method: method, signature: signature, body: body)
        } catch {
            return Promise(error: error)
        }
    }

    func request(
        path: String,
        parameters: RequestParameters,
        method: APIMethod,
        signature: String? = nil,
        body: Data? = nil
    ) -> Promise<JSONObject> {
        return firstly {
            try self.send(createRequest(path: path, parameters: parameters, signature: signature, method: method, body: body))
        }
    }
    
    private func createRequest(path: String, parameters: RequestParameters, signature: String?, method: APIMethod, body: Data?) throws -> URLRequest {
        var components = URLComponents()
        components.scheme = "https"
        components.host = path.starts(with: "ppd") || path.starts(with: "questionnaire") ? "api.keyn.app" : Properties.keynApi
        components.path = "/\(Properties.environment.path)/\(path)"

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


    private func send(_ request: URLRequest) -> Promise<JSONObject> {
        return firstly {
            return urlSession!.dataTask(with: request)
        }.map { response, data in
            if response.statusCode == 200 {
                guard !data.isEmpty else {
                    throw APIError.noData
                }
                let jsonData = try JSONSerialization.jsonObject(with: data, options: [])
                guard let json = jsonData as? JSONObject else {
                    throw APIError.jsonSerialization
                }
                return json
            } else {
                throw APIError.statusCode(response.statusCode)
            }
        }
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
