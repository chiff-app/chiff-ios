//
//  api.swift
//  keyn
//
//  Created by bas on 19/08/2018.
//  Copyright © 2018 keyn. All rights reserved.
//

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
}

enum APIRequestType: String {
    case get = "GET"
    case put = "PUT"
    case post = "POST"
    case delete = "DELETE"
}

class API {
    
    static let sharedInstance = API()
    
    private init() {}
    
    func put(type: APIEndpoint, path: String, parameters: [String: String]) {
        let url = createUrl(type: type, path: path, parameters: parameters)!
        var request = URLRequest(url: url)
        request.httpMethod = APIRequestType.put.rawValue
        send(request)
    }
    
    func get(type: APIEndpoint, path: String, parameters: [String: String]?, completionHandler: @escaping (_ accountData: [String: Any]) -> Void) {
        let url = createUrl(type: type, path: path, parameters: parameters)!
        var request = URLRequest(url: url)
        request.httpMethod = APIRequestType.get.rawValue
        send(request, completionHandler: completionHandler)
    }
    
    func post(type: APIEndpoint, path: String, parameters: [String: String], body: [String: String]?) throws {
        let url = createUrl(type: type, path: path, parameters: parameters)!
        var request = URLRequest(url: url)
        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        }
        request.httpMethod = APIRequestType.post.rawValue
        send(request)
    }
    
    func delete(type: APIEndpoint, path: String, parameters: [String: String], body: [String: String]?) throws {
        let url = createUrl(type: type, path: path, parameters: parameters)!
        var request = URLRequest(url: url)
        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        }
        request.httpMethod = APIRequestType.delete.rawValue
        send(request)
    }
    
    private func send(_ request: URLRequest, completionHandler: ((_ result: [String: Any]) -> Void)? = nil) {
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
                    Logger.shared.error("API error", error: error as NSError, userInfo: [
                        "statusCode": httpStatus.statusCode
                        ])
                }
            } else {
                Logger.shared.error("API error. Wrong Response type")
            }
        }
        task.resume()
    }
    
    private func createUrl(type: APIEndpoint, path: String, parameters: [String: String]?) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = Properties.keynApi
        components.path = "/\(Properties.keynApiVersion)/\(type.rawValue)/\(path)"
        if let parameters = parameters {
            var queryItems = [URLQueryItem]()
            for (key, value) in parameters {
                let item = URLQueryItem(name: key, value: value)
                queryItems.append(item)
            }
            components.queryItems = queryItems
        }
        return components.url
    }
    
}
