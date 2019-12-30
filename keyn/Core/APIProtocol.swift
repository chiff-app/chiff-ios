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

//enum APIEndpoint: String {
//    case devices = "devices"
//    case users = "users"
//    case sessions = "sessions"
//    case teams = "teams"
//    case teamsUsers = "teams/users"
//    case news = "news"
//    case questionnaire = "questionnaires"
//    case subscriptions = "subscriptions"
//    case iosSubscriptions = "subscription/ios"
//    case ppd = "ppd"
//    case analytics = "analytics"
//    case pairing = "pairing"
//    case volatile = "volatile"
//    case appToBrowser = "app-to-browser"
//    case browserToApp = "browser-to-app"
//    case userAccounts
//
//    static func path(endpoint: APIEndpoint, for pubkey: String, id: String?) -> String {
//        switch endpoint {
//        case userAccounts:
//            if let id = id {
//                return "\(APIEndpoint.users.rawValue)/\(pubkey)/accounts/\(id)"
//            } else {
//                return "\(APIEndpoint.users.rawValue)/\(pubkey)/accounts"
//            }
//        }
//    }
//
//    static func usersAccounts(for pubkey: String, id: String?) -> String {
//        if let id = id {
//            return "\(APIEndpoint.users.rawValue)/\(pubkey)/accounts/\(id)"
//        } else {
//            return "\(APIEndpoint.users.rawValue)/\(pubkey)/accounts"
//        }
//    }
//
//    static func sessionsAccounts(for pubkey: String, id: String?) -> String {
//        if let id = id {
//            return "\(APIEndpoint.sessions.rawValue)/\(pubkey)/accounts/\(id)"
//        } else {
//            return "\(APIEndpoint.sessions.rawValue)/\(pubkey)/accounts"
//        }
//    }
//
//    static func pairing(for pubkey: String) -> String {
//        return "\(APIEndpoint.sessions.rawValue)/\(pubkey)/pairing"
//    }
//
//    static func volatile(for pubkey: String) -> String {
//        return "\(APIEndpoint.sessions.rawValue)/\(pubkey)/volatile"
//    }
//
//    static func appToBrowser(for pubkey: String) -> String {
//        return "\(APIEndpoint.sessions.rawValue)/\(pubkey)/app-to-browser"
//    }
//
//    static func browserToApp(for pubkey: String) -> String {
//        return "\(APIEndpoint.sessions.rawValue)/\(pubkey)/browser-to-app"
//    }
//
//}

enum APIMethod: String {
    case get = "GET"
    case put = "PUT"
    case post = "POST"
    case delete = "DELETE"
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
