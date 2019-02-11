/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import Foundation
import JustLog

enum APIError: Error {
    case url
    case jsonSerialization(error: String)
    case request(error: Error)
    case statusCode(error: String)
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

enum APIRequestType: String {
    case get = "GET"
    case put = "PUT"
    case post = "POST"
    case delete = "DELETE"
}

class API {
    static let shared = API()

    private init() {}

    func put(type: APIEndpoint, path: String, parameters: [String: String]) throws {
        let request = try createRequest(type: type, path: path, parameters: parameters, method: .put)
        send(request)
    }

    func get(type: APIEndpoint, path: String?, parameters: [String: String]?, completionHandler: @escaping (_ result: [String: Any]?) -> Void) throws {
        let request = try createRequest(type: type, path: path, parameters: parameters, method: .get)
        send(request, completionHandler: completionHandler)
    }

    func post(type: APIEndpoint, path: String, parameters: [String: String]) throws {
        let request = try createRequest(type: type, path: path, parameters: parameters, method: .post)
        send(request)
    }

    func delete(type: APIEndpoint, path: String, parameters: [String: String]) throws {
        let request = try createRequest(type: type, path: path, parameters: parameters, method: .delete)
        send(request)
    }

    private func send(_ request: URLRequest, completionHandler: ((_ result: [String: Any]?) -> Void)? = nil) {
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                Logger.shared.warning("Error querying Keyn API", error: error! as NSError)
                return
            }
            if let httpStatus = response as? HTTPURLResponse {
                do {
                    if httpStatus.statusCode == 200 {
                        let jsonData = try JSONSerialization.jsonObject(with: data, options: [])
                        guard let json = jsonData as? [String: Any] else {
                            throw APIError.jsonSerialization(error: "Could not convert json to dict")
                        }
                        if let completionHandler = completionHandler {
                            completionHandler(json)
                        }
                    } else if let error = error {
                        throw APIError.request(error: error)
                    } else {
                        throw APIError.statusCode(error: "Not 200 but no error")
                    }
                } catch {
                    if let completionHandler = completionHandler {
                        completionHandler(nil)
                    }
                    Logger.shared.error("API error", error: error as NSError, userInfo: [
                        "statusCode": httpStatus.statusCode
                    ])
                }
            } else {
                if let completionHandler = completionHandler {
                    completionHandler(nil)
                }
                Logger.shared.error("API error. Wrong Response type")
            }
        }
        task.resume()
    }

    private func createRequest(type: APIEndpoint, path: String?, parameters: [String: String]?, method: APIRequestType) throws -> URLRequest {
        var components = URLComponents()
        components.scheme = "https"
        components.host = Properties.keynApi
        components.path = "/\(Properties.ppdTestingMode ? Properties.keynApiVersion.development : Properties.keynApiVersion.production)/\(type.rawValue)"

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
