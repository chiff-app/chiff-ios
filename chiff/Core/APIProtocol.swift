//
//  APIProtocol.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import Foundation
import PromiseKit
import PMKFoundation

enum APIError: Error {
    case url
    case jsonSerialization
    case request(error: Error)
    case statusCode(Int)
    case noResponse
    case noData
    case response
    case wrongResponseType
    case pinninigError
    case urlSize
}

enum APIMethod: String {
    case get = "GET"
    case put = "PUT"
    case post = "POST"
    case delete = "DELETE"
    case patch = "PATCH"
}

extension URLSession {

    func dataTask(with url: URLRequest) -> Promise<(HTTPURLResponse, Data)> {
        return dataTask(.promise, with: url).map { (data, response) in
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.wrongResponseType
            }
            return (httpResponse, data)
        }
    }
}

typealias JSONObject = [String: Any]

protocol APIProtocol {
    func signedRequest(path: String, method: APIMethod, privKey: Data, message: JSONObject?, body: Data?, parameters: [String: String]?) -> Promise<JSONObject>
    func signedRequest<T>(path: String, method: APIMethod, privKey: Data, message: JSONObject?, body: Data?, parameters: [String: String]?) -> Promise<T>
    func request(path: String, method: APIMethod, signature: String?, body: Data?, parameters: [String: String]?) -> Promise<JSONObject>
    func request<T>(path: String, method: APIMethod, signature: String?, body: Data?, parameters: [String: String]?) -> Promise<T>
}

extension APIProtocol {
    func signedRequest(path: String, method: APIMethod, privKey: Data, message: JSONObject? = nil, body: Data? = nil, parameters: [String: String]? = nil) -> Promise<JSONObject> {
        return signedRequest(path: path, method: method, privKey: privKey, message: message, body: body, parameters: parameters)
    }

    func signedRequest<T>(path: String, method: APIMethod, privKey: Data, message: JSONObject? = nil, body: Data? = nil, parameters: [String: String]? = nil) -> Promise<T> {
        return signedRequest(path: path, method: method, privKey: privKey, message: message, body: body, parameters: parameters)
    }

    func request(path: String, method: APIMethod, signature: String? = nil, body: Data? = nil, parameters: [String: String]? = nil) -> Promise<JSONObject> {
        return request(path: path, method: method, signature: signature, body: body, parameters: parameters)
    }

    func request<T>(path: String, method: APIMethod, signature: String? = nil, body: Data? = nil, parameters: [String: String]? = nil) -> Promise<T> {
        return request(path: path, method: method, signature: signature, body: body, parameters: parameters)
    }
}
