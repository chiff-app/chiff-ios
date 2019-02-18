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

class Session: Codable {
    let id: String
    let messagePubKey: String
    let controlPubKey: String
    let pushPubKey: String
    let encryptionPubKey: String
    let creationDate: Date
    let browser: String
    let os: String
    var backgroundTask: UIBackgroundTaskIdentifier = UIBackgroundTaskIdentifier.invalid

    private static let messageQueueService = "io.keyn.session.message"
    private static let controlQueueService = "io.keyn.session.control"
    private static let appService = "io.keyn.session.app"

    private enum KeyIdentifier: String, Codable {
        case pub = "public"
        case priv = "private"
        case control = "control"
        case message = "message"
        case push = "push"

        func identifier(for id:String) -> String {
            return "\(id)-\(self.rawValue)"
        }
    }

    init(encryptionPubKey: String, messagePubKey: String, controlPubKey: String, pushPubKey: String, browser: String, os: String) {
        self.encryptionPubKey = encryptionPubKey
        self.messagePubKey = messagePubKey
        self.controlPubKey = controlPubKey
        self.pushPubKey = pushPubKey
        self.creationDate = Date()
        self.browser = browser
        self.os = os
        self.id = "\(encryptionPubKey)_\(messagePubKey)".hash
    }

    func delete(includingQueue: Bool) throws {
        Logger.shared.analytics("Session ended.", code: .sessionEnd, userInfo: ["appInitiated": includingQueue])
        if includingQueue {
            try sendToControlQueue(message: "Ynll") // Is base64encoded for bye
        }
        try deleteEndpointAtAWS()
        try Keychain.shared.delete(id: KeyIdentifier.control.identifier(for: id), service: Session.controlQueueService)
        try Keychain.shared.delete(id: KeyIdentifier.push.identifier(for: id), service: Session.controlQueueService)
        try Keychain.shared.delete(id: KeyIdentifier.message.identifier(for: id), service: Session.messageQueueService)
        try Keychain.shared.delete(id: KeyIdentifier.pub.identifier(for: id), service: Session.appService)
        try Keychain.shared.delete(id: KeyIdentifier.priv.identifier(for: id), service: Session.appService)
    }

    func browserPublicKey() throws -> Data {
        return try Crypto.shared.convertFromBase64(from: encryptionPubKey)
    }

    func appPrivateKey() throws -> Data {
        return try Keychain.shared.get(id: KeyIdentifier.priv.identifier(for: id), service: Session.appService)
    }

    func appPublicKey() throws -> Data {
        return try Keychain.shared.get(id: KeyIdentifier.pub.identifier(for: id), service: Session.appService)
    }

    func decrypt(message: String) throws -> String {
        let ciphertext = try Crypto.shared.convertFromBase64(from: message)
        let (data, _) = try Crypto.shared.decrypt(ciphertext, privKey: appPrivateKey(), pubKey: browserPublicKey())
        return String(data: data, encoding: .utf8)!
    }

    func decrypt(message: String) throws -> BrowserMessage {
        let ciphertext = try Crypto.shared.convertFromBase64(from: message)
        let (data, _) = try Crypto.shared.decrypt(ciphertext, privKey: appPrivateKey(), pubKey: browserPublicKey())
        let browserMessage = try JSONDecoder().decode(BrowserMessage.self, from: data)
        return browserMessage
    }

    func acknowledge(browserTab: Int, completionHandler: @escaping (_ res: [String: Any]?, _ error: Error?) -> Void) {
        do {
            let response = CredentialsResponse(u: nil, p: nil, np: nil, b: browserTab, a: nil, o: nil)
            let jsonMessage = try JSONEncoder().encode(response)
            let ciphertext = try Crypto.shared.encrypt(jsonMessage, pubKey: browserPublicKey(), privKey: appPrivateKey())
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
        let ciphertext = try Crypto.shared.encrypt(message, pubKey: Crypto.shared.convertFromBase64(from: encryptionPubKey), privKey: appPrivateKey())
        try sendToMessageQueue(ciphertext: ciphertext, type: type) { (_, error) in
            if let error = error {
                Logger.shared.error("Error sending credentials", error: error)
            }
        }
    }

    // TODO: This is now different from deleteChangeConfirmation with the signing error, make it the same.
    func getChangeConfirmations(shortPolling: Bool, completionHandler: @escaping (_ res: [String: Any]?, _ error: Error?) -> Void) {
        guard let parameters = try? sign(data: nil, requestType: .get, privKey: Keychain.shared.get(id: KeyIdentifier.control.identifier(for: id), service: Session.controlQueueService), type: nil, waitTime: shortPolling ? "0" : "20") else {
            // Logger.shared.warning("Failed to get password change confirmation from queue (signing problem).")
            return completionHandler(nil, SessionError.signing)
        }

        API.shared.request(type: .message, path: controlPubKey, parameters: parameters, method: .get) { (res, error) in
            if let error = error {
                Logger.shared.warning("Failed to get password change confirmation from queue.", error: error)
                completionHandler(nil, error)
            }
            if let res = res {
                completionHandler(res, nil)
            }
        }
    }

    func deleteChangeConfirmation(receiptHandle: String) {
        guard let parameters = try? sign(data: nil, requestType: .delete, privKey: Keychain.shared.get(id: KeyIdentifier.control.identifier(for: id), service: Session.controlQueueService), type: nil, receiptHandle: receiptHandle) else {
            return Logger.shared.warning("Failed to delete password change confirmation from queue (signing problem).")
        }

        API.shared.request(type: .message, path: controlPubKey, parameters: parameters, method: .delete) { (_, error) in
            if let error = error {
                Logger.shared.warning("Failed to delete password change confirmation from queue.", error: error)
            }
        }
    }

    // MARK: - Static functions

    static func all() throws -> [Session] {
        var sessions = [Session]()
        
        guard let dataArray = try Keychain.shared.all(service: messageQueueService) else {
            return sessions
        }

        let decoder = PropertyListDecoder()

        for dict in dataArray {
            guard let sessionData = dict[kSecAttrGeneric as String] as? Data else {
                throw CodingError.unexpectedData
            }
            sessions.append(try decoder.decode(Session.self, from: sessionData))
        }
        return sessions
    }

    static func exists(encryptionPubKey: String, queueSeed: String) throws -> Bool {
        let seed = try Crypto.shared.deriveKey(key: queueSeed, context: "message", index: 1)
        let messageKeyPair = try Crypto.shared.createSigningKeyPair(seed: seed)
        let messagePubKey = try Crypto.shared.convertToBase64(from: messageKeyPair.publicKey.data)
        let id = "\(encryptionPubKey)_\(messagePubKey)".hash
        return Keychain.shared.has(id: KeyIdentifier.message.identifier(for: id), service: Session.messageQueueService)
    }

    static func exists(id: String) throws -> Bool {
        return Keychain.shared.has(id: KeyIdentifier.message.identifier(for: id), service: Session.messageQueueService)
    }

    static func getSession(id: String) throws -> Session? {
        guard let sessionDict = try Keychain.shared.attributes(id: KeyIdentifier.message.identifier(for: id), service: Session.messageQueueService) else {
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
        Keychain.shared.deleteAll(service: messageQueueService)
        Keychain.shared.deleteAll(service: controlQueueService)
        Keychain.shared.deleteAll(service: appService)
    }

    // TODO: Call this function with succes and error handlers. Remove throws.
    static func initiate(queueSeed: String, pubKey: String, browser: String, os: String) throws -> Session {
        // Create session and save to Keychain
        // TODO: Think if we can combine the keys for the two message + control queue.
        let messageKeyPair = try Crypto.shared.createSigningKeyPair(seed: Crypto.shared.deriveKey(key: queueSeed, context: "message", index: 1))
        let controlKeyPair = try Crypto.shared.createSigningKeyPair(seed: Crypto.shared.deriveKey(key: queueSeed, context: "control", index: 2))
        let pushKeyPair = try Crypto.shared.createSigningKeyPair(seed: Crypto.shared.deriveKey(key: queueSeed, context: "pushpush", index: 3))
        let messagePubKey = try Crypto.shared.convertToBase64(from: messageKeyPair.publicKey.data)
        let controlPubKey = try Crypto.shared.convertToBase64(from: controlKeyPair.publicKey.data)
        let pushPubKey = try Crypto.shared.convertToBase64(from: pushKeyPair.publicKey.data)
        let session = Session(encryptionPubKey: pubKey, messagePubKey: messagePubKey, controlPubKey: controlPubKey, pushPubKey: pushPubKey, browser: browser, os: os)

        do {
            try session.save(messagePrivKey: messageKeyPair.secretKey.data, controlPrivKey: controlKeyPair.secretKey.data, pushPrivKey: pushKeyPair.secretKey.data)
        } catch is KeychainError {
            throw SessionError.exists
        } catch is CryptoError {
            throw SessionError.invalid
        }

        let pairingResponse = try self.createPairingResponse(session: session)
        try session.sendToMessageQueue(ciphertext: pairingResponse, type: BrowserMessageType.pair) { (_, error) in
            if let error = error {
                Logger.shared.error("Error initiating session.", error: error)
            }
        }

        return session
    }

    // MARK: - Private

    private func sendToMessageQueue(ciphertext: Data, type: BrowserMessageType, completionHandler: @escaping (_ res: [String: Any]?, _ error: Error?) -> Void) throws {
        let data = try Crypto.shared.convertToBase64(from: ciphertext)
        let parameters = try sign(data: data, requestType: .post, privKey: Keychain.shared.get(id: KeyIdentifier.message.identifier(for: id), service: Session.messageQueueService), type: type)

        API.shared.request(type: .message, path: messagePubKey, parameters: parameters, method: .post, completionHandler: completionHandler)
    }

    private func sendToControlQueue(message: String) throws {
        let parameters = try sign(data: message, requestType: .post, privKey: Keychain.shared.get(id: KeyIdentifier.control.identifier(for: id), service: Session.controlQueueService), type: .end)
        API.shared.request(type: .message, path: controlPubKey, parameters: parameters, method: .post) { (_, error) in
            if let error = error {
                Logger.shared.error("Cannot send message to control queue.", error: error)
            }
        }
    }

    private func authorizePushMessages(endpoint: String) throws {
        let parameters = try sign(data: endpoint, requestType: .put, privKey: Keychain.shared.get(id: KeyIdentifier.push.identifier(for: id), service: Session.controlQueueService), type: nil)
        API.shared.request(type: .push, path: pushPubKey, parameters: parameters, method: .put) { (_, error) in
            if let error = error {
                Logger.shared.error("Cannot authorize push messages.", error: error)
            }
        }
    }

    private func deleteEndpointAtAWS() throws {
        let parameters = try sign(data: nil, requestType: .delete, privKey: Keychain.shared.get(id: KeyIdentifier.push.identifier(for: id), service: Session.controlQueueService), type: nil)
        API.shared.request(type: .push, path: pushPubKey, parameters: parameters, method: .delete) { (_, error) in
            if let error = error {
                Logger.shared.error("Cannot delete endpoint as AWS.", error: error)
            }
        }
    }

    static private func createPairingResponse(session: Session) throws -> Data {
        guard let endpoint = AWS.shared.snsDeviceEndpointArn else {
            throw SessionError.noEndpoint
        }
        let pairingResponse = try PairingResponse(sessionID: session.id, pubKey: Crypto.shared.convertToBase64(from: session.appPublicKey()), sns: endpoint, userID: Properties.userID())
        let jsonPasswordMessage = try JSONEncoder().encode(pairingResponse)

        // TODO: Voor nu error loggen, maar als dit niet lukt dan werkt de sessie niet dus hier moeten we wat mee.
        try session.authorizePushMessages(endpoint: endpoint)

        return try Crypto.shared.encrypt(jsonPasswordMessage, pubKey: session.browserPublicKey())
    }

    private func save(messagePrivKey: Data, controlPrivKey: Data, pushPrivKey: Data) throws {
        // Save browser public key

        let sessionData = try PropertyListEncoder().encode(self) // Now contains public keys
        try Keychain.shared.save(id: KeyIdentifier.message.identifier(for: id), service: Session.messageQueueService, secretData: messagePrivKey, objectData: sessionData, classification: .restricted)
        try Keychain.shared.save(id: KeyIdentifier.control.identifier(for: id), service: Session.controlQueueService, secretData: controlPrivKey, classification: .restricted)
        try Keychain.shared.save(id: KeyIdentifier.push.identifier(for: id), service: Session.controlQueueService, secretData: pushPrivKey, classification: .restricted)

        // Generate and save own keypair1
        let keyPair = try Crypto.shared.createSessionKeyPair()
        try Keychain.shared.save(id: KeyIdentifier.pub.identifier(for: id), service: Session.appService, secretData: keyPair.publicKey.data, classification: .restricted)
        try Keychain.shared.save(id: KeyIdentifier.priv.identifier(for: id), service: Session.appService, secretData: keyPair.secretKey.data,classification: .restricted)
    }

    private func sign(data: String?, requestType: APIMethod, privKey: Data, type: BrowserMessageType?, waitTime: String? = nil, receiptHandle: String? = nil) throws -> [String:String] {
        var message = [
            "type": requestType.rawValue,
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
        let signature = try Crypto.shared.sign(message: jsonData, privKey: privKey)

        var parameters = [
            "m": try Crypto.shared.convertToBase64(from: jsonData),
            "s": try Crypto.shared.convertToBase64(from: signature)
        ]
        if let type = type {
            parameters["t"] = String(type.rawValue)
        }

        return parameters
    }
}
