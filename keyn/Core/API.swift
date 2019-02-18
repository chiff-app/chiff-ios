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
}

enum APIEndpoint: String {
    case backup = "backup"
    case ppd = "ppd"
    case analytics = "analytics"
    case queue = "queue"
    case message = "message"
    case questionnaire = "questionnaire"
    case push = "push"
}

enum APIMethod: String {
    case get = "GET"
    case put = "PUT"
    case post = "POST"
    case delete = "DELETE"
}

class API {
    
    static let shared = API()

    private init() {}

    // TODO: Misschien kan dit `typealias JSONDictionary  [String: Any]`?
    func request(type: APIEndpoint, path: String?, parameters: [String: String]?, method: APIMethod, completionHandler: @escaping (_ res: [String: Any]?, _ error: Error?) -> Void) {
        do {
            let request = try createRequest(type: type, path: path, parameters: nil, method: method)
            send(request, completionHandler: completionHandler)
        } catch {
            completionHandler(nil, error)
        }
    }

    // MARK: - Private

    private func send(_ request: URLRequest, completionHandler: @escaping (_ res: [String: Any]?, _ error: Error?) -> Void) {
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                Logger.shared.warning("Error querying Keyn API", error: error!)
                return
            }
            if let httpStatus = response as? HTTPURLResponse {
                do {
                    if httpStatus.statusCode == 200 {
                        let jsonData = try JSONSerialization.jsonObject(with: data, options: [])
                        guard let json = jsonData as? [String: Any] else {
                            throw APIError.jsonSerialization
                        }
                        completionHandler(json, nil)
                    } else if let error = error {
                        throw APIError.request(error: error)
                    } else {
                        throw APIError.statusCode(httpStatus.statusCode)
                    }
                } catch {
                    Logger.shared.error("API error", error: error)
                    completionHandler(nil, error)
                }
            } else {
                Logger.shared.error("API error. Wrong Response type")
                completionHandler(nil, APIError.wrongResponseType)
            }
        }
        task.resume()
    }

    private func createRequest(type: APIEndpoint, path: String?, parameters: [String: String]?, method: APIMethod) throws -> URLRequest {
        var components = URLComponents()
        components.scheme = "https"
        components.host = Properties.keynApi
        components.path = "/\(Properties.isDebug ? Properties.keynApiVersion.development : Properties.keynApiVersion.production)/\(type.rawValue)"

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

        return request
    }
}
