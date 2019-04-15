/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit
import UserNotifications
import LocalAuthentication

enum SessionError: KeynError {
    case exists
    case doesntExist
    case invalid
    case noEndpoint
    case signing
    case unknownType
    case destroyed
}

fileprivate enum KeyIdentifier: String, Codable {
    case sharedKey = "shared"
    case signingKeyPair = "signing"

    func identifier(for id: String) -> String {
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

    func delete(notifyExtension: Bool) throws {
        Logger.shared.analytics("Session ended.", code: .sessionEnd, userInfo: ["appInitiated": notifyExtension])
        if notifyExtension {
            try sendByeToPersistentQueue() { (_, error) in
                if let error = error {
                    Logger.shared.error("Error sending bye to persistent queue.", error: error)
                }
            }
        } else { // App should delete the queues
            deleteQueuesAtAWS()
        }
        try Keychain.shared.delete(id: KeyIdentifier.sharedKey.identifier(for: id), service: .sharedSessionKey)
        try Keychain.shared.delete(id: KeyIdentifier.signingKeyPair.identifier(for: id), service: .signingSessionKey)
    }

    func decrypt(message message64: String) throws -> KeynRequest {
        let ciphertext = try Crypto.shared.convertFromBase64(from: message64)
        let (data, _) = try Crypto.shared.decrypt(ciphertext, key: sharedKey())
        var message = try JSONDecoder().decode(KeynRequest.self, from: data)
        message.sessionID = id
        return message
    }

    func decrypt(message message64: String) throws -> KeynPersistentQueueMessage {
        let ciphertext = try Crypto.shared.convertFromBase64(from: message64)
        let (data, _) = try Crypto.shared.decrypt(ciphertext, key: sharedKey())
        return try JSONDecoder().decode(KeynPersistentQueueMessage.self, from: data)
    }

    func cancelRequest(reason: KeynMessageType, browserTab: Int, completionHandler: @escaping (_ res: [String: Any]?, _ error: Error?) -> Void) {
        do {
            let response = KeynCredentialsResponse(u: nil, p: nil, np: nil, b: browserTab, a: nil, o: nil, t: reason)
            let jsonMessage = try JSONEncoder().encode(response)
            let ciphertext = try Crypto.shared.encrypt(jsonMessage, key: sharedKey())
            try sendToVolatileQueue(ciphertext: ciphertext, completionHandler: completionHandler)
        } catch {
            completionHandler(nil, error)
        }
    }



    /// This sends the credentials back to the browser extension.
    ///
    /// - Parameters:
    ///   - account: The account
    ///   - browserTab: The browser tab
    ///   - type: The response type
    ///   - context: The LocalAuthenticationContext. This should already be authenticated, otherwise this function will fail
    func sendCredentials(account: Account, browserTab: Int, type: KeynMessageType, context: LAContext) throws {
        var account = account
        let password = try account.password(context: context)
        var response: KeynCredentialsResponse?
        switch type {
        case .change:
            response = KeynCredentialsResponse(u: account.username, p: password, np: try account.nextPassword(context: context), b: browserTab, a: account.id, o: nil, t: .change)
            NotificationCenter.default.post(name: .passwordChangeConfirmation, object: self, userInfo: ["context": context])
        case .add:
            response = KeynCredentialsResponse(u: nil, p: nil, np: nil, b: browserTab, a: nil, o: nil, t: .add)
        case .login, .addAndLogin:
            response = KeynCredentialsResponse(u: account.username, p: password, np: nil, b: browserTab, a: nil, o: try account.oneTimePasswordToken()?.currentPassword, t: .login)
            Logger.shared.analytics("Login response sent.", code: .loginResponse, userInfo: ["siteName": account.site.name])
        case .fill:
            Logger.shared.analytics("Fill password response sent.", code: .fillResponse, userInfo: ["siteName": account.site.name])
            response = KeynCredentialsResponse(u: nil, p: password, np: nil, b: browserTab, a: nil, o: nil, t: .fill)
        case .register:
            Logger.shared.analytics("Register response sent.", code: .registrationResponse, userInfo: ["siteName": account.site.name])
            response = KeynCredentialsResponse(u: account.username, p: password, np: nil, b: browserTab, a: nil, o: nil, t: .register)
        default:
            throw SessionError.unknownType
        }

        let message = try JSONEncoder().encode(response!)
        let ciphertext = try Crypto.shared.encrypt(message, key: self.sharedKey())

        try self.sendToVolatileQueue(ciphertext: ciphertext) { (_, error) in
            if let error = error {
                Logger.shared.error("Error sending credentials", error: error)
            }
        }
    }

    func getPersistentQueueMessages(shortPolling: Bool, completionHandler: @escaping (_ messages: [KeynPersistentQueueMessage]?, _ error: Error?) -> Void) {
        let message = [
            "waitTime": shortPolling ? "0" : "20"
        ]
        apiRequest(endpoint: .persistentBrowserToApp, method: .get, message: message) { (res, error) in
            do {
                if let error = error {
                    throw error
                }
                guard let data = res, let sqsMessages = data["messages"] as? [[String:String]] else {
                    throw CodingError.missingData
                }
                let messages = try sqsMessages.map({ (message) -> KeynPersistentQueueMessage in
                    guard let body = message[MessageParameter.body], let receiptHandle = message[MessageParameter.receiptHandle] else {
                        throw CodingError.missingData
                    }
                    var keynMessage: KeynPersistentQueueMessage = try self.decrypt(message: body)
                    keynMessage.receiptHandle = receiptHandle
                    return keynMessage
                })
                completionHandler(messages, nil)
            } catch {
                completionHandler(nil, error)
            }
        }
    }

    func deleteFromPersistentQueue(receiptHandle: String) {
        let message = [
            "receiptHandle": receiptHandle
        ]
        apiRequest(endpoint: .persistentBrowserToApp, method: .delete, message: message) { (_, error) in
            if let error = error {
                Logger.shared.warning("Failed to delete password change confirmation from queue.", error: error)
            }
        }
    }

    func updateAccountList(with accountList: AccountList) throws {
        let message = try JSONEncoder().encode(accountList)
        let ciphertext = try Crypto.shared.encrypt(message, key: sharedKey())
        apiRequest(endpoint: .accounts, method: .post, message: ["data": ciphertext.base64]) { (_, error) in
            if let error = error {
                Logger.shared.warning("Failed to send account list to persistent queue.", error: error)
            }
        }
    }

    // MARK: - Static

    static func all() throws -> [Session] {
        var sessions = [Session]()

        guard let dataArray = try Keychain.shared.all(service: .sharedSessionKey) else {
            return sessions
        }

        let decoder = PropertyListDecoder()

        for dict in dataArray {
            guard let sessionData = dict[kSecAttrGeneric as String] as? Data else {
                throw CodingError.unexpectedData
            }
            do {
                let session = try decoder.decode(Session.self, from: sessionData)
                sessions.append(session)
            } catch {
                Logger.shared.error("Can not decode session", error: error)
                do {
                    if let sessionId = dict[kSecAttrAccount as String] as? String {
                        try Keychain.shared.delete(id: sessionId, service: .sharedSessionKey)
                    } else {
                        purgeSessionDataFromKeychain()
                    }
                } catch {
                    purgeSessionDataFromKeychain()
                }
            }
        }

        return sessions
    }

    static func exists(id: String) throws -> Bool {
        return Keychain.shared.has(id: KeyIdentifier.sharedKey.identifier(for: id), service: .sharedSessionKey)
    }

    static func get(id: String) throws -> Session? {
        guard let sessionDict = try Keychain.shared.attributes(id: KeyIdentifier.sharedKey.identifier(for: id), service: .sharedSessionKey) else {
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
                try session.delete(notifyExtension: true)
            }
        } catch {
            Logger.shared.debug("Error deleting sessions.", error: error)
        }

        // To be sure
        purgeSessionDataFromKeychain()
    }

    static func initiate(pairingQueueSeed: String, browserPubKey: String, browser: String, os: String, completion: (_ session: Session?, _ error: Error?) -> Void) {
        do {
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

            completion(session, nil)
        } catch {
            Logger.shared.error("Error initiating session", error: error)
            completion(nil, error)
        }
    }

    // MARK: - Private

    private func createQueues(signingKeyPair: KeyPair) throws {
        guard let deviceEndpoint = BackupManager.shared.endpoint else {
            throw SessionError.noEndpoint
        }

        // The creation of volatile and persistent queues as well as the pushmessage endpoint is one atomic operation.
        createQueuesAtAWS(keyPair: signingKeyPair, deviceEndpoint: deviceEndpoint) { (_, error) in
            if let error = error {
                Logger.shared.error("Cannot create SQS queues and SNS endpoint.", error: error)
            }
        }
    }

    private func acknowledgeSessionStartToBrowser(pairingKeyPair: KeyPair, browserPubKey: Data, sharedKeyPubkey: String) throws {
        let pairingResponse = KeynPairingResponse(sessionID: id, pubKey: sharedKeyPubkey, userID: Properties.userID(), sandboxed: Properties.isDebug, accounts: try Account.accountList(), type: .pair)
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
        Keychain.shared.deleteAll(service: .sharedSessionKey)
        Keychain.shared.deleteAll(service: .signingSessionKey)
    }

    private func sendToVolatileQueue(ciphertext: Data, completionHandler: @escaping (_ res: [String: Any]?, _ error: Error?) -> Void) throws {
        let message = [
            "data": try Crypto.shared.convertToBase64(from: ciphertext)
        ]
        apiRequest(endpoint: .volatile, method: .post, message: message, completionHandler: completionHandler)
    }

    private func sendByeToPersistentQueue(completionHandler: @escaping (_ res: [String: Any]?, _ error: Error?) -> Void) throws {
        let message = try JSONEncoder().encode(KeynPersistentQueueMessage(passwordSuccessfullyChanged: nil, accountID: nil, type: .end, askToLogin: nil, askToChange: nil, receiptHandle: nil))
        let ciphertext = try Crypto.shared.encrypt(message, key: sharedKey())
        apiRequest(endpoint: .persistentAppToBrowser, method: .post, message: ["data": ciphertext.base64]) { (_, error) in
            if let error = error {
                Logger.shared.error("Cannot send message to control queue.", error: error)
            }
        }
    }

    private func sharedKey() throws -> Data {
        return try Keychain.shared.get(id: KeyIdentifier.sharedKey.identifier(for: id), service: .sharedSessionKey)
    }

    private func save(key: Data, signingKeyPair: KeyPair) throws {
        let sessionData = try PropertyListEncoder().encode(self)
        try Keychain.shared.save(id: KeyIdentifier.sharedKey.identifier(for: id), service: .sharedSessionKey, secretData: key, objectData: sessionData)
        try Keychain.shared.save(id: KeyIdentifier.signingKeyPair.identifier(for: id), service: .signingSessionKey, secretData: signingKeyPair.privKey)
    }

    private func apiRequest(endpoint: APIEndpoint, method: APIMethod, message: [String: Any]? = nil, privKey: Data? = nil, pubKey: String? = nil, completionHandler: @escaping (_ res: [String: Any]?, _ error: Error?) -> Void) {
        var message = message ?? [:]
        message["httpMethod"] = method.rawValue
        message["timestamp"] = String(Int(Date().timeIntervalSince1970))

        do {
            let privKey = try privKey ?? Keychain.shared.get(id: KeyIdentifier.signingKeyPair.identifier(for: id), service: .signingSessionKey)
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

    private func createQueuesAtAWS(keyPair: KeyPair, deviceEndpoint: String, completionHandler: @escaping (_ res: [String: Any]?, _ error: Error?) -> Void) {
        var message = [
            "httpMethod": APIMethod.put.rawValue,
            "timestamp": String(Int(Date().timeIntervalSince1970)),
            "pubkey": keyPair.pubKey.base64,
            "deviceEndpoint": deviceEndpoint
        ]

        do {
            let accountData = try JSONEncoder().encode(Account.accountList())
            let ciphertext = try Crypto.shared.encrypt(accountData, key: sharedKey())
            message["accountList"] = ciphertext.base64
            let jsonData = try JSONSerialization.data(withJSONObject: message, options: [])
            let signature = try Crypto.shared.sign(message: jsonData, privKey: keyPair.privKey)

            let parameters = [
                "m": try Crypto.shared.convertToBase64(from: jsonData),
                "s": try Crypto.shared.convertToBase64(from: signature)
            ]

            API.shared.request(endpoint: .message, path: nil, parameters: parameters, method: .put, completionHandler: completionHandler)
        } catch {
            completionHandler(nil, error)
        }
    }

    private func deleteQueuesAtAWS() {
        let message = [
            "httpMethod": APIMethod.delete.rawValue,
            "timestamp": String(Int(Date().timeIntervalSince1970)),
            "pubkey": signingPubKey
        ]

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: message, options: [])
            let signature = try Crypto.shared.sign(message: jsonData, privKey: Keychain.shared.get(id: KeyIdentifier.signingKeyPair.identifier(for: id), service: .signingSessionKey))

            let parameters = [
                "m": try Crypto.shared.convertToBase64(from: jsonData),
                "s": try Crypto.shared.convertToBase64(from: signature)
            ]

            API.shared.request(endpoint: .message, path: nil, parameters: parameters, method: .delete) { _, error in
                if let error = error {
                    Logger.shared.error("Cannot delete endpoint at AWS.", error: error)
                }
            }
        } catch {
            Logger.shared.error("Cannot delete endpoint at AWS.", error: error)
        }
    }

}
