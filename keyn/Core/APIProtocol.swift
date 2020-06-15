/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import Foundation
import PromiseKit

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

typealias JSONObject = Dictionary<String, Any>

protocol APIProtocol {
    func signedRequest(method: APIMethod, message: JSONObject?, path: String, privKey: Data, body: Data?, parameters: [String:String]?) -> Promise<JSONObject>
    func request(path: String, parameters: [String:String]?, method: APIMethod, signature: String?, body: Data?) -> Promise<JSONObject>
}
