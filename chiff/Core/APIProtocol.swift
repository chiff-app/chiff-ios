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

/// Send requests to the Chiff back-end.
protocol APIProtocol {
    /// Sends a request to the back-end, signing the message with the provided private key.
    /// The `timestamp` and `method` will be added to the message before signing, as they are required for all requests.
    /// - Parameters:
    ///   - path: The path that should be appended to the endpoint. Should *not* start with a slash.
    ///   - method: The HTTP method.
    ///   - privKey: The private key that will be used to sign the message.
    ///   - message: Optionally, a dictionary of attributes that need to be signed. The `timestamp` and `method` will be added automatically to the message before signing.
    ///   - body: Optionally, a message body. Will not be signed.
    ///   - parameters: Optionally, additional query parameters.
    /// - Returns: The promise of a JSONObject. Can be disregarded by using the the `asVoid()` method of PromiseKit.
    func signedRequest(path: String, method: APIMethod, privKey: Data, message: JSONObject?, body: Data?, parameters: [String: String]?) -> Promise<JSONObject>

    /// Sends a request to the back-end, signing the message with the provided private key.
    /// The `timestamp` and `method` will be added to the message before signing, as they are required for all requests.
    /// - Parameters:
    ///   - path: The path that should be appended to the endpoint. Should *not* start with a slash.
    ///   - method: The HTTP method.
    ///   - privKey: The private key that will be used to sign the message.
    ///   - message: Optionally, a dictionary of attributes that need to be signed. The `timestamp` and `method` will be added automatically to the message before signing.
    ///   - body: Optionally, a message body. Will not be signed.
    ///   - parameters: Optionally, additional query parameters.
    /// - Returns: The promise of a `T` object, where the result should be castable to `T`.
    func signedRequest<T>(path: String, method: APIMethod, privKey: Data, message: JSONObject?, body: Data?, parameters: [String: String]?) -> Promise<T>

    /// Sends an unsigned request to the back-end.
    /// - Parameters:
    ///   - path: The path that should be appended to the endpoint. Should *not* start with a slash.
    ///   - method: The HTTP method.
    ///   - signature: Optionally, a signature may be provided.
    ///   - body: Optionally, a message body. Calculating and providing the correct signature over the body, if needed, is the responsibility of the caller.
    ///   - parameters: Optionally, additional query parameters.
    /// - Returns: The promise of a JSONObject. Can be disregarded by using the the `asVoid()` method of PromiseKit.
    func request(path: String, method: APIMethod, signature: String?, body: Data?, parameters: [String: String]?) -> Promise<JSONObject>

    /// Sends an unsigned request to the back-end.
    /// - Parameters:
    ///   - path: The path that should be appended to the endpoint. Should *not* start with a slash.
    ///   - method: The HTTP method.
    ///   - signature: Optionally, a signature may be provided.
    ///   - body: Optionally, a message body. Calculating and providing the correct signature over the body, if needed, is the responsibility of the caller.
    ///   - parameters: Optionally, additional query parameters.
    /// - Returns: The promise of a `T` object, where the result should be castable to `T`.
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
