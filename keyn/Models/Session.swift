/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit
import UserNotifications

enum SessionError: KeynError {
    case exists
    case invalid
    case noEndpoint
    case signing
    case unknownType
}

fileprivate enum KeyIdentifier: String, Codable {
    case sharedKey = "shared"
    case signingKeyPair = "signing"

    var service: String {
        return "io.keyn.session.\(self.rawValue)"
    }

    func identifier(for id:String) -> String {
        return "\(id)-\(self.rawValue)"
    }
}

enum MessageType: String {
    case pairing, volatile, persistent, push
}

/*
 * There is a non-codable part of session that is only stored in the Keychain.
 * That is: sharedKey and sigingKeyPair.privKey.
 */
class Session: Codable {
    let id: String
    let creationDate: Date
    let signingPubKey: String
    let browser: String
    let os: String
    // This used to be a UIBackgroundTaskIdentifier, but that gave us vague decoding errors.
    var backgroundTask: Int = UIBackgroundTaskIdentifier.invalid.rawValue

    init(browser: String, os: String, signingPubKey: Data, id: String) {
        self.creationDate = Date()
        self.signingPubKey = signingPubKey.base64
        self.browser = browser
        self.os = os
        self.id = id
    }

    func delete(includingQueue: Bool) throws {
        Logger.shared.analytics("Session ended.", code: .sessionEnd, userInfo: ["appInitiated": includingQueue])
        if includingQueue {
            sendToPersistentQueue(message: "Ynll") // Is base64encoded for bye
        }
        deleteEndpointAtAWS()
        try Keychain.shared.delete(id: KeyIdentifier.sharedKey.identifier(for: id), service: KeyIdentifier.sharedKey.service)
        try Keychain.shared.delete(id: KeyIdentifier.signingKeyPair.identifier(for: id), service: KeyIdentifier.signingKeyPair.service)
    }

    func decrypt(message: String) throws -> BrowserMessage {
        let ciphertext = try Crypto.shared.convertFromBase64(from: message)
        let (data, _) = try Crypto.shared.decrypt(ciphertext, key: sharedKey())
        let browserMessage = try JSONDecoder().decode(BrowserMessage.self, from: data)
        return browserMessage
    }

    func acknowledge(browserTab: Int, completionHandler: @escaping (_ res: [String: Any]?, _ error: Error?) -> Void) {
        do {
            let response = CredentialsResponse(u: nil, p: nil, np: nil, b: browserTab, a: nil, o: nil)
            let jsonMessage = try JSONEncoder().encode(response)
            let ciphertext = try Crypto.shared.encrypt(jsonMessage, key: sharedKey())
            try sendToMessageQueue(ciphertext: ciphertext, type: BrowserMessageType.acknowledge, completionHandler: completionHandler)
        } catch {
            completionHandler(nil, error)
        }
    }

    // TODO, add request ID etc
    func sendCredentials(account: Account, browserTab: Int, type: BrowserMessageType) throws {
        var response: CredentialsResponse?
        var account = account
        switch type {
        case .addAndChange:
            response = CredentialsResponse(u: account.username, p: account.password, np: try account.nextPassword(), b: browserTab, a: account.id, o: nil)
            NotificationCenter.default.post(name: .passwordChangeConfirmation, object: self)
        case .change:
            response = CredentialsResponse(u: account.username, p: account.password, np: try account.nextPassword(), b: browserTab, a: account.id, o: nil)
            NotificationCenter.default.post(name: .passwordChangeConfirmation, object: self)
        case .add:
            response = CredentialsResponse(u: account.username, p: account.password, np: nil, b: browserTab, a: nil, o: try account.oneTimePasswordToken()?.currentPassword)
        case .login:
            Logger.shared.analytics("Login response sent.", code: .loginResponse, userInfo: ["siteName": account.site.name])
            response = CredentialsResponse(u: account.username, p: account.password, np: nil, b: browserTab, a: nil, o: try account.oneTimePasswordToken()?.currentPassword)
        case .fill:
            Logger.shared.analytics("Fill password response sent.", code: .fillResponse, userInfo: ["siteName": account.site.name])
            response = CredentialsResponse(u: nil, p: account.password, np: nil, b: browserTab, a: nil, o: nil)
        case .register:
            Logger.shared.analytics("Register response sent.", code: .registrationResponse, userInfo: ["siteName": account.site.name])
            // TODO: create new account, set password etc.
            response = CredentialsResponse(u: account.username, p: account.password, np: nil, b: browserTab, a: nil, o: nil)
        case .acknowledge:
            response = CredentialsResponse(u: nil, p: nil, np: nil, b: browserTab, a: nil, o: nil)
        default:
            throw SessionError.unknownType
        }

        let message = try JSONEncoder().encode(response!)
        let ciphertext = try Crypto.shared.encrypt(message, key: sharedKey())
        try sendToMessageQueue(ciphertext: ciphertext, type: type) { (_, error) in
            if let error = error {
                Logger.shared.error("Error sending credentials", error: error)
            }
        }
    }

    // TODO: This is now different from deleteChangeConfirmation with the signing error, make it the same.
    func getChangeConfirmations(shortPolling: Bool, completionHandler: @escaping (_ res: [String: Any]?, _ error: Error?) -> Void) {
        apiRequest(endpoint: .persistent, method: .get, waitTime: shortPolling ? "0" : "20") { (res, error) in
            if let res = res {
                completionHandler(res, nil)
            }
            if let error = error {
                Logger.shared.warning("Failed to get password change confirmation from queue.", error: error)
                completionHandler(nil, error)
            }
        }
    }

    func deleteChangeConfirmation(receiptHandle: String) {
        apiRequest(endpoint: .persistent, method: .delete, receiptHandle: receiptHandle) { (_, error) in
            if let error = error {
                Logger.shared.warning("Failed to delete password change confirmation from queue.", error: error)
            }
        }
    }

    // MARK: - Static

    static func all() throws -> [Session] {
        var sessions = [Session]()
        
        guard let dataArray = try Keychain.shared.all(service: KeyIdentifier.sharedKey.service) else {
            return sessions
        }

        let decoder = PropertyListDecoder()

        for dict in dataArray {
            guard let sessionData = dict[kSecAttrGeneric as String] as? Data else {
                throw CodingError.unexpectedData
            }
            // TODO: If not decodable, remove specific session instead of all.
            do {
                let session = try decoder.decode(Session.self, from: sessionData)
                sessions.append(session)
            } catch {
                Logger.shared.error("Can not decode session, deleting all session data from keychain.", error: error)
                purgeSessionDataFromKeychain()
            }
        }

        return sessions
    }

    static func exists(id: String) throws -> Bool {
        return Keychain.shared.has(id: KeyIdentifier.sharedKey.identifier(for: id), service: KeyIdentifier.sharedKey.service)
    }

    static func get(id: String) throws -> Session? {
        guard let sessionDict = try Keychain.shared.attributes(id: KeyIdentifier.sharedKey.identifier(for: id), service: KeyIdentifier.sharedKey.service) else {
            return nil
        }
        guard let sessionData = sessionDict[kSecAttrGeneric as String] as? Data else {
            throw CodingError.unexpectedData
        }
        let decoder = PropertyListDecoder()
        return try decoder.decode(Session.self, from: sessionData)
    }

    static func deleteAll() {
        do {
            for session in try Session.all() {
                try session.delete(includingQueue: true)
            }
        } catch {
            Logger.shared.debug("Error deleting sessions.", error: error)
        }

        // To be sure
        purgeSessionDataFromKeychain()
    }

    // TODO: Call this function with succes and error handlers. Remove throws.
    static func initiate(pairingQueuePrivKey: String, browserPubKey: String, browser: String, os: String) throws -> Session {
        // Create session and save to Keychain
        let keyPair = try Crypto.shared.createSessionKeyPair()
        let sharedKey = try Crypto.shared.generateSharedKey(pubKey: browserPubKey, privKey: keyPair.privKey)
        let signingKeyPair = try Crypto.shared.createSigningKeyPair(seed: sharedKey)
        let session = Session(browser: browser, os: os, signingPubKey: signingKeyPair.pubKey, id: browserPubKey.hash)

        do {
            try session.save(key: sharedKey, signingKeyPair: signingKeyPair)
        } catch is KeychainError {
            throw SessionError.exists
        } catch is CryptoError {
            throw SessionError.invalid
        }

        try session.sendPairingResponse()

        return session
    }

    // MARK: - Private
    
    private static func purgeSessionDataFromKeychain() {
        Keychain.shared.deleteAll(service: KeyIdentifier.sharedKey.service)
        Keychain.shared.deleteAll(service: KeyIdentifier.signingKeyPair.service)
    }

    private func sendToMessageQueue(ciphertext: Data, type: BrowserMessageType, completionHandler: @escaping (_ res: [String: Any]?, _ error: Error?) -> Void) throws {
        let data = try Crypto.shared.convertToBase64(from: ciphertext)
        apiRequest(endpoint: .message, method: .post, data: data, type: type, completionHandler: completionHandler)
    }

    private func sendToPersistentQueue(message: String) {
        apiRequest(endpoint: .persistent, method: .post, data: message, type: .end) { (_, error) in
            if let error = error {
                Logger.shared.error("Cannot send message to control queue.", error: error)
            }
        }
    }

    private func authorizePushMessages(endpoint: String) {
        apiRequest(endpoint: .push, method: .put) { (_, error) in
            if let error = error {
                Logger.shared.error("Cannot authorize push messages.", error: error)
            }
        }
    }

    private func deleteEndpointAtAWS() {
        apiRequest(endpoint: .message, method: .delete) { (_, error) in
            if let error = error {
                Logger.shared.error("Cannot delete endpoint as AWS.", error: error)
            }
        }
    }

    private func sendPairingResponse() throws {
        guard let endpoint = AWS.shared.snsDeviceEndpointArn else {
            throw SessionError.noEndpoint
        }
        let pairingResponse = PairingResponse(sessionID: id, pubKey: signingPubKey, sns: endpoint, userID: Properties.userID())
        let jsonPairingResponse = try JSONEncoder().encode(pairingResponse)

        // TODO: Voor nu error loggen, maar als dit niet lukt dan werkt de sessie niet dus hier moeten we wat mee.
        authorizePushMessages(endpoint: endpoint)
        let ciphertext = try Crypto.shared.encrypt(jsonPairingResponse, key: sharedKey())
        try sendToMessageQueue(ciphertext: ciphertext, type: BrowserMessageType.pair) { (_, error) in
            if let error = error {
                Logger.shared.error("Error initiating session.", error: error)
            }
        }
    }

    private func sharedKey() throws -> Data {
        return try Keychain.shared.get(id: KeyIdentifier.sharedKey.identifier(for: id), service: KeyIdentifier.sharedKey.service)
    }

    private func save(key: Data, signingKeyPair: KeyPair) throws {
        let sessionData = try PropertyListEncoder().encode(self)
        try Keychain.shared.save(id: KeyIdentifier.sharedKey.identifier(for: id), service: KeyIdentifier.sharedKey.service, secretData: key, objectData: sessionData, classification: .restricted)
        try Keychain.shared.save(id: KeyIdentifier.signingKeyPair.identifier(for: id), service: KeyIdentifier.signingKeyPair.service, secretData: signingKeyPair.privKey, classification: .restricted)
    }

    private func apiRequest(endpoint: APIEndpoint, method: APIMethod, data: String? = nil, type: BrowserMessageType? = nil, waitTime: String? = nil, receiptHandle: String? = nil, completionHandler: @escaping (_ res: [String: Any]?, _ error: Error?) -> Void) {
        do {
            var message = [
                "type": method.rawValue,
                "timestamp": String(Int(Date().timeIntervalSince1970))
            ]
            if let data = data {
                message["data"] = data
            }
            if let waitTime = waitTime {
                message["waitTime"] = waitTime
            }
            if let receiptHandle = receiptHandle {
                message["receiptHandle"] = receiptHandle
            }

            let jsonData = try JSONSerialization.data(withJSONObject: message, options: [])
            let privKey = try Keychain.shared.get(id: KeyIdentifier.signingKeyPair.identifier(for: id), service: KeyIdentifier.signingKeyPair.service)
            let signature = try Crypto.shared.sign(message: jsonData, privKey: privKey)

            var parameters = [
                "m": try Crypto.shared.convertToBase64(from: jsonData),
                "s": try Crypto.shared.convertToBase64(from: signature)
            ]
            if let type = type {
                parameters["t"] = String(type.rawValue)
            }

            API.shared.request(endpoint: endpoint, path: signingPubKey, parameters: parameters, method: method, completionHandler: completionHandler)
        } catch {
            completionHandler(nil, error)
        }
    }

}
