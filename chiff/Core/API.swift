//
//  API.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

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

    func signedRequest(path: String, method: APIMethod, privKey: Data, message: JSONObject? = nil, body: Data? = nil, parameters: [String: String]? = nil) -> Promise<JSONObject> {
        var message = message ?? [:]
        message["httpMethod"] = method.rawValue
        message["timestamp"] = Date.now
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: message, options: [])
            let signature = (try Crypto.shared.signature(message: jsonData, privKey: privKey)).base64
            var parameters = parameters ?? [:]
            parameters["m"] = try Crypto.shared.convertToBase64(from: jsonData)
            return request(path: path, method: method, signature: signature, body: body, parameters: parameters)
        } catch {
            return Promise(error: error)
        }
    }

    func signedRequest<T>(path: String, method: APIMethod, privKey: Data, message: JSONObject? = nil, body: Data? = nil, parameters: [String: String]? = nil) -> Promise<T> {
        var message = message ?? [:]
        message["httpMethod"] = method.rawValue
        message["timestamp"] = Date.now
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: message, options: [])
            let signature = (try Crypto.shared.signature(message: jsonData, privKey: privKey)).base64
            var parameters = parameters ?? [:]
            parameters["m"] = try Crypto.shared.convertToBase64(from: jsonData)
            return request(path: path, method: method, signature: signature, body: body, parameters: parameters)
        } catch {
            return Promise(error: error)
        }
    }

    func request(
        path: String,
        method: APIMethod,
        signature: String? = nil,
        body: Data? = nil,
        parameters: [String: String]? = nil
    ) -> Promise<JSONObject> {
        return firstly {
            try self.send(createRequest(path: path, parameters: parameters, signature: signature, method: method, body: body))
        }
    }

    func request<T>(
        path: String,
        method: APIMethod,
        signature: String? = nil,
        body: Data? = nil,
        parameters: [String: String]? = nil
    ) -> Promise<T> {
        return firstly {
            try self.send(createRequest(path: path, parameters: parameters, signature: signature, method: method, body: body))
        }
    }

    private func createRequest(path: String, parameters: [String: String]?, signature: String?, method: APIMethod, body: Data?) throws -> URLRequest {
        var components = URLComponents()
        components.scheme = "https"
        components.host = Properties.keynApi
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
        guard url.absoluteString.count < 8192 else {
            throw APIError.urlSize // AWS will do it otherwise
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

    private func send<T>(_ request: URLRequest) -> Promise<T> {
        return firstly {
            return urlSession!.dataTask(with: request)
        }.map { response, data in
            if response.statusCode == 200 {
                guard !data.isEmpty else {
                    throw APIError.noData
                }
                let jsonData = try JSONSerialization.jsonObject(with: data, options: [])
                guard let json = jsonData as? T else {
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
