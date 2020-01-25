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


enum APIMethod: String {
    case get = "GET"
    case put = "PUT"
    case post = "POST"
    case delete = "DELETE"
    case patch = "PATCH"
}

extension URLSession {
    func dataTask(with url: URLRequest, result: @escaping (Result<(HTTPURLResponse, Data), Error>) -> Void) -> URLSessionDataTask {
        return dataTask(with: url) { (data, response, error) in
            if let error = error {
                return result(.failure(error))
            }
            
            guard let data = data else {
                return result(.failure(APIError.noData))
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

    func signedRequest(method: APIMethod, message: JSONObject?, path: String, privKey: Data, body: Data?, completionHandler: @escaping (Result<JSONObject, Error>) -> Void)

    func request(path: String, parameters: RequestParameters, method: APIMethod, signature: String?, body: Data?, completionHandler: @escaping (Result<JSONObject, Error>) -> Void)

}
