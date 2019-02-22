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

    var backgroundTask: Int = UIBackgroundTaskIdentifier.invalid.rawValue
    let browser: String
    let creationDate: Date
    let id: String
    let os: String
    let signingPubKey: String

    init(id: String, signingPubKey: Data, browser: String, os: String) {
        self.creationDate = Date()
        self.id = id
        self.signingPubKey = signingPubKey.base64
        self.browser = browser
        self.os = os
    }

    func delete(includingQueue: Bool) throws {
        Logger.shared.analytics("Session ended.", code: .sessionEnd, userInfo: ["appInitiated": includingQueue])
        if includingQueue {
            try sendByeToPersistentQueue() { (_, error) in
                if let error = error {
                    Logger.shared.error("Error sending bye to persistent queue.", error: error)
                }
            }
        }
        deleteEndpointAtAWS()
        try Keychain.shared.delete(id: KeyIdentifier.sharedKey.identifier(for: id), service: KeyIdentifier.sharedKey.service)
        try Keychain.shared.delete(id: KeyIdentifier.signingKeyPair.identifier(for: id), service: KeyIdentifier.signingKeyPair.service)
    }

    func decrypt(message message64: String) throws -> KeynRequest {
        let ciphertext = try Crypto.shared.convertFromBase64(from: message64)
        let (data, _) = try Crypto.shared.decrypt(ciphertext, key: sharedKey())
        let message = try JSONDecoder().decode(KeynRequest.self, from: data)
        return message
    }

    func reject(browserTab: Int, completionHandler: @escaping (_ res: [String: Any]?, _ error: Error?) -> Void) {
        do {
            let response = KeynCredentialsResponse(u: nil, p: nil, np: nil, b: browserTab, a: nil, o: nil, t: .reject)
            let jsonMessage = try JSONEncoder().encode(response)
            let ciphertext = try Crypto.shared.encrypt(jsonMessage, key: sharedKey())
            try sendToVolatileQueue(ciphertext: ciphertext, completionHandler: completionHandler)
        } catch {
            completionHandler(nil, error)
        }
    }

    // TODO: Add request ID etc - Wat bedoel je Bas?
    func sendCredentials(account: Account, browserTab: Int, type: KeynMessageType) throws {
        var response: KeynCredentialsResponse?
        var account = account

        switch type {
        case .addAndChange: // TODO: Deprecated?
            response = KeynCredentialsResponse(u: account.username, p: account.password, np: try account.nextPassword(), b: browserTab, a: account.id, o: nil, t: .addAndChange)
            NotificationCenter.default.post(name: .passwordChangeConfirmation, object: self)
        case .change:
            response = KeynCredentialsResponse(u: account.username, p: account.password, np: try account.nextPassword(), b: browserTab, a: account.id, o: nil, t: .change)
            NotificationCenter.default.post(name: .passwordChangeConfirmation, object: self)
        case .add:
            response = KeynCredentialsResponse(u: account.username, p: account.password, np: nil, b: browserTab, a: nil, o: try account.oneTimePasswordToken()?.currentPassword, t: .add)
        case .login:
            Logger.shared.analytics("Login response sent.", code: .loginResponse, userInfo: ["siteName": account.site.name])
            response = KeynCredentialsResponse(u: account.username, p: account.password, np: nil, b: browserTab, a: nil, o: try account.oneTimePasswordToken()?.currentPassword, t: .login)
        case .fill:
            Logger.shared.analytics("Fill password response sent.", code: .fillResponse, userInfo: ["siteName": account.site.name])
            response = KeynCredentialsResponse(u: nil, p: account.password, np: nil, b: browserTab, a: nil, o: nil, t: .fill)
        case .register:
            Logger.shared.analytics("Register response sent.", code: .registrationResponse, userInfo: ["siteName": account.site.name])
            // TODO: create new account, set password etc.
            response = KeynCredentialsResponse(u: account.username, p: account.password, np: nil, b: browserTab, a: nil, o: nil, t: .register)
        case .acknowledge:
            response = KeynCredentialsResponse(u: nil, p: nil, np: nil, b: browserTab, a: nil, o: nil, t: .acknowledge)
        default:
            throw SessionError.unknownType
        }

        let message = try JSONEncoder().encode(response!)
        let ciphertext = try Crypto.shared.encrypt(message, key: sharedKey())

        try sendToVolatileQueue(ciphertext: ciphertext) { (_, error) in
            if let error = error {
                Logger.shared.error("Error sending credentials", error: error)
            }
        }
    }

    // TODO: This is now different from deleteChangeConfirmation with the signing error, make it the same.
    func getChangeConfirmations(shortPolling: Bool, completionHandler: @escaping (_ res: [String: Any]?, _ error: Error?) -> Void) {
        let message = [
            "waitTime": shortPolling ? "0" : "20"
        ]
        apiRequest(endpoint: .persistent, method: .get, message: message) { (res, error) in
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
        let message = [
            "receiptHandle": receiptHandle
        ]
        apiRequest(endpoint: .persistent, method: .delete, message: message) { (_, error) in
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
    static func initiate(pairingQueueSeed: String, browserPubKey: String, browser: String, os: String) throws -> Session {
        let keyPairForSharedKey = try Crypto.shared.createSessionKeyPair()
        let browserPubKeyData = try Crypto.shared.convertFromBase64(from: browserPubKey)
        let sharedKey = try Crypto.shared.generateSharedKey(pubKey: browserPubKeyData, privKey: keyPairForSharedKey.privKey)
        let signingKeyPair = try Crypto.shared.createSigningKeyPair(seed: sharedKey)

        let pairingKeyPair = try Crypto.shared.createSigningKeyPair(seed: Crypto.shared.convertFromBase64(from: pairingQueueSeed))

        let session = Session(id: browserPubKey.hash, signingPubKey: signingKeyPair.pubKey, browser: browser, os: os)
        do {
            try session.save(key: sharedKey, signingKeyPair: signingKeyPair)
        } catch is KeychainError {
            throw SessionError.exists
        } catch is CryptoError {
            throw SessionError.invalid
        }

        try session.createQueues(signingKeyPair: signingKeyPair)
        try session.acknowledgeSessionStartToBrowser(pairingKeyPair: pairingKeyPair, browserPubKey: browserPubKeyData, sharedKeyPubkey: keyPairForSharedKey.pubKey.base64)

        return session
    }

    // MARK: - Private

    private func createQueues(signingKeyPair: KeyPair) throws {
        guard let deviceEndpoint = AWS.shared.snsDeviceEndpointArn else {
            throw SessionError.noEndpoint
        }

        // The creation of volatile and persistent queues as well as the pushmessage endpoint is one atomic operation.
        apiRequestForCreatingQueues(endpoint: .message, method: .put, keyPair: signingKeyPair, deviceEndpoint: deviceEndpoint) { (_, error) in
            if let error = error {
                Logger.shared.error("Cannot create SQS queues and SNS endpoint.", error: error)
            }
        }
    }

    private func acknowledgeSessionStartToBrowser(pairingKeyPair: KeyPair, browserPubKey: Data, sharedKeyPubkey: String) throws {
        let pairingResponse = KeynPairingResponse(sessionID: id, pubKey: sharedKeyPubkey, userID: Properties.userID(), sandboxed: Properties.isDebug, type: .pair)
        let jsonPairingResponse = try JSONEncoder().encode(pairingResponse)
        let ciphertext = try Crypto.shared.encrypt(jsonPairingResponse, pubKey: browserPubKey)
        let ciphertextBase64 = try Crypto.shared.convertToBase64(from: ciphertext)

        let message = [
            "data": ciphertextBase64
        ]
        apiRequest(endpoint: .pairing, method: .post, message: message, privKey: pairingKeyPair.privKey, pubKey: pairingKeyPair.pubKey.base64) { (_, error) in
            if let error = error {
                Logger.shared.error("Error sending pairing response.", error: error)
            }
        }
    }

    private static func purgeSessionDataFromKeychain() {
        Keychain.shared.deleteAll(service: KeyIdentifier.sharedKey.service)
        Keychain.shared.deleteAll(service: KeyIdentifier.signingKeyPair.service)
    }

    private func sendToVolatileQueue(ciphertext: Data, completionHandler: @escaping (_ res: [String: Any]?, _ error: Error?) -> Void) throws {
        let message = [
            "data": try Crypto.shared.convertToBase64(from: ciphertext)
        ]
        apiRequest(endpoint: .volatile, method: .post, message: message, completionHandler: completionHandler)
    }

    // TODO: Heeft deze een bericht type?
    private func sendByeToPersistentQueue(completionHandler: @escaping (_ res: [String: Any]?, _ error: Error?) -> Void) throws {
        let message = [
            "data": "Ynll" // Base64 'bye' for fun and gezelligheid.
        ]
        apiRequest(endpoint: .persistent, method: .post, message: message) { (_, error) in
            if let error = error {
                Logger.shared.error("Cannot send message to control queue.", error: error)
            }
        }
    }

    private func deleteEndpointAtAWS() {
        apiRequest(endpoint: .message, method: .delete) { (_, error) in
            if let error = error {
                Logger.shared.error("Cannot delete endpoint at AWS.", error: error)
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

    private func apiRequest(endpoint: APIEndpoint, method: APIMethod, message: [String: Any]? = nil, privKey: Data? = nil, pubKey: String? = nil, completionHandler: @escaping (_ res: [String: Any]?, _ error: Error?) -> Void) {
        var message = message ?? [:]
        message["httpMethod"] = method.rawValue
        message["timestamp"] = String(Int(Date().timeIntervalSince1970))

        do {
            let privKey = try privKey ?? Keychain.shared.get(id: KeyIdentifier.signingKeyPair.identifier(for: id), service: KeyIdentifier.signingKeyPair.service)
            let jsonData = try JSONSerialization.data(withJSONObject: message, options: [])
            let signature = try Crypto.shared.sign(message: jsonData, privKey: privKey)

            let parameters = [
                "m": try Crypto.shared.convertToBase64(from: jsonData),
                "s": try Crypto.shared.convertToBase64(from: signature)
            ]

            API.shared.request(endpoint: endpoint, path: pubKey ?? signingPubKey, parameters: parameters, method: method, completionHandler: completionHandler)
        } catch {
            completionHandler(nil, error)
        }
    }

    // TODO: Later combine this with other apiRequest function?
    private func apiRequestForCreatingQueues(endpoint: APIEndpoint, method: APIMethod, keyPair: KeyPair, deviceEndpoint: String, completionHandler: @escaping (_ res: [String: Any]?, _ error: Error?) -> Void) {
        let message = [
            "httpMethod": method.rawValue,
            "timestamp": String(Int(Date().timeIntervalSince1970)),
            "pubkey": keyPair.pubKey.base64,
            "deviceEndpoint": deviceEndpoint
        ]

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: message, options: [])
            let signature = try Crypto.shared.sign(message: jsonData, privKey: keyPair.privKey)

            let parameters = [
                "m": try Crypto.shared.convertToBase64(from: jsonData),
                "s": try Crypto.shared.convertToBase64(from: signature)
            ]

            API.shared.request(endpoint: endpoint, path: nil, parameters: parameters, method: method, completionHandler: completionHandler)
        } catch {
            completionHandler(nil, error)
        }
    }

}
