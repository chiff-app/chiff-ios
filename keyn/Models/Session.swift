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
        print("SendCredentials called")
        var account = account
        var response: KeynCredentialsResponse?
        switch type {
        case .change:
            response = KeynCredentialsResponse(u: account.username, p: try account.password(context: context), np: try account.nextPassword(context: context), b: browserTab, a: account.id, o: nil, t: .change)
            NotificationCenter.default.post(name: .passwordChangeConfirmation, object: self, userInfo: ["context": context])
        case .add, .addToExisting, .addAndLogin:
            response = KeynCredentialsResponse(u: nil, p: nil, np: nil, b: browserTab, a: nil, o: nil, t: .add)
        case .login:
            response = KeynCredentialsResponse(u: account.username, p: try account.password(context: context), np: nil, b: browserTab, a: nil, o: try account.oneTimePasswordToken()?.currentPassword, t: .login)
            Logger.shared.analytics("Login response sent.", code: .loginResponse, userInfo: nil)
        case .fill:
            Logger.shared.analytics("Fill password response sent.", code: .fillResponse, userInfo: nil)
            response = KeynCredentialsResponse(u: nil, p: try account.password(context: context), np: nil, b: browserTab, a: nil, o: nil, t: .fill)
        case .register:
            Logger.shared.analytics("Register response sent.", code: .registrationResponse, userInfo: nil)
            response = KeynCredentialsResponse(u: account.username, p: try account.password(context: context), np: nil, b: browserTab, a: nil, o: nil, t: .register)
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
        do {
            API.shared.signedRequest(endpoint: .persistentBrowserToApp, method: .get, message: message, pubKey: signingPubKey, privKey: try signingPrivKey()) { (res, error) in
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
        } catch {
            completionHandler(nil, error)
        }
    }

    func deleteFromPersistentQueue(receiptHandle: String) {
        let message = [
            "receiptHandle": receiptHandle
        ]
        do {
            API.shared.signedRequest(endpoint: .persistentBrowserToApp, method: .delete, message: message, pubKey: signingPubKey, privKey: try signingPrivKey()) { (_, error) in
                if let error = error {
                    Logger.shared.warning("Failed to delete password change confirmation from queue.", error: error)
                }
            }
        } catch {
            Logger.shared.warning("Failed to get privkey from Keychain", error: error)
        }
    }

    func updateAccountList(account: Account) throws {
        let accountData = try JSONEncoder().encode(JSONAccount(account: account))
        let ciphertext = try Crypto.shared.encrypt(accountData, key: sharedKey())
        let message = [
            "id": account.id,
            "data": ciphertext.base64
        ]
        API.shared.signedRequest(endpoint: .accounts, method: .post, message: message, pubKey: signingPubKey, privKey: try signingPrivKey()) { (_, error) in
            if let error = error {
                Logger.shared.warning("Failed to send account list to persistent queue.", error: error)
            }
        }
    }

    func deleteAccount(accountId: String) {
        do {
            API.shared.signedRequest(endpoint: .accounts, method: .delete, message: ["id": accountId], pubKey: signingPubKey, privKey: try signingPrivKey()) { (_, error) in
                if let error = error {
                    Logger.shared.warning("Failed to send account list to persistent queue.", error: error)
                }
            }
        } catch {
            Logger.shared.warning("Failed to signing privkey from Keychain", error: error)
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

    static func initiate(pairingQueueSeed: String, browserPubKey: String, browser: String, os: String, completion: @escaping (_ session: Session?, _ error: Error?) -> Void) {
        do {
            let keyPairForSharedKey = try Crypto.shared.createSessionKeyPair()
            let browserPubKeyData = try Crypto.shared.convertFromBase64(from: browserPubKey)
            let sharedKey = try Crypto.shared.generateSharedKey(pubKey: browserPubKeyData, privKey: keyPairForSharedKey.privKey)
            let signingKeyPair = try Crypto.shared.createSigningKeyPair(seed: sharedKey)

            let pairingKeyPair = try Crypto.shared.createSigningKeyPair(seed: Crypto.shared.convertFromBase64(from: pairingQueueSeed))

            let session = Session(id: browserPubKey.hash, signingPubKey: signingKeyPair.pubKey, browser: browser, os: os)
            let group = DispatchGroup()
            var groupError: Error?
            group.enter()
            try session.createQueues(signingKeyPair: signingKeyPair, sharedKey: sharedKey) { error in
                if groupError == nil {
                    groupError = error
                }
                group.leave()
            }
            group.enter()
            try session.acknowledgeSessionStartToBrowser(pairingKeyPair: pairingKeyPair, browserPubKey: browserPubKeyData, sharedKeyPubkey: keyPairForSharedKey.pubKey.base64)  { error in
                if groupError == nil {
                    groupError = error
                }
                group.leave()
            }
            group.notify(queue: .main) {
                do {
                    if let error = groupError {
                        throw error
                    }
                    try session.save(key: sharedKey, signingKeyPair: signingKeyPair)
                    completion(session, nil)
                } catch is KeychainError {
                    completion(nil, SessionError.exists)
                } catch is CryptoError {
                    completion(nil, SessionError.invalid)
                } catch {
                    completion(nil, error)
                }
            }
        } catch {
            Logger.shared.error("Error initiating session", error: error)
            completion(nil, error)
        }
    }

    static func purgeSessionDataFromKeychain() {
        Keychain.shared.deleteAll(service: .sharedSessionKey)
        Keychain.shared.deleteAll(service: .signingSessionKey)
    }


    // MARK: - Private

    private func decrypt(message message64: String) throws -> KeynPersistentQueueMessage {
        let ciphertext = try Crypto.shared.convertFromBase64(from: message64)
        let (data, _) = try Crypto.shared.decrypt(ciphertext, key: sharedKey())
        return try JSONDecoder().decode(KeynPersistentQueueMessage.self, from: data)
    }

    private func createQueues(signingKeyPair keyPair: KeyPair, sharedKey: Data, completion: @escaping (_ error: Error?) -> Void) throws {
        guard let deviceEndpoint = NotificationManager.shared.endpoint else {
            throw SessionError.noEndpoint
        }

        var message: [String: Any] = [
            "httpMethod": APIMethod.put.rawValue,
            "timestamp": String(Int(Date().timeIntervalSince1970)),
            "pubkey": keyPair.pubKey.base64,
            "deviceEndpoint": deviceEndpoint
        ]

        do {
            let encryptedAccounts = try Account.accountList().mapValues { (account) -> String in
                let accountData = try JSONEncoder().encode(account)
                return try Crypto.shared.encrypt(accountData, key: sharedKey).base64
            }
            message["accountList"] = encryptedAccounts
            let jsonData = try JSONSerialization.data(withJSONObject: message, options: [])
            let signature = try Crypto.shared.signature(message: jsonData, privKey: keyPair.privKey)

            let parameters = [
                "s": try Crypto.shared.convertToBase64(from: signature)
            ]
            API.shared.request(endpoint: .message, path: nil, parameters: parameters, method: .put, body: jsonData) { (_, error) in
                if let error = error {
                    Logger.shared.error("Cannot create SQS queues and SNS endpoint.", error: error)
                    completion(error)
                } else {
                    completion(nil)
                }
            }
        } catch {
            completion(error)
        }
    }

    private func acknowledgeSessionStartToBrowser(pairingKeyPair: KeyPair, browserPubKey: Data, sharedKeyPubkey: String, completion: @escaping (_ error: Error?) -> Void) throws {
        let pairingResponse = KeynPairingResponse(sessionID: id, pubKey: sharedKeyPubkey, browserPubKey: browserPubKey.base64, userID: Properties.userId!, environment: Properties.environment.rawValue, accounts: try Account.accountList(), type: .pair, errorLogging: Properties.errorLogging, analyticsLogging: Properties.analyticsLogging)
        let jsonPairingResponse = try JSONEncoder().encode(pairingResponse)
        let ciphertext = try Crypto.shared.encrypt(jsonPairingResponse, pubKey: browserPubKey)
        let signedCiphertext = try Crypto.shared.sign(message: ciphertext, privKey: pairingKeyPair.privKey)
        let message = [
            "data": signedCiphertext.base64
        ]
        let jsonData = try JSONSerialization.data(withJSONObject: message, options: [])
        API.shared.signedRequest(endpoint: .pairing, method: .post, pubKey: pairingKeyPair.pubKey.base64, privKey: pairingKeyPair.privKey, body: jsonData) { (_, error) in
            if let error = error {
                Logger.shared.error("Error sending pairing response.", error: error)
                completion(error)
            } else {
                completion(nil)
            }
        }
    }

    private func sendToVolatileQueue(ciphertext: Data, completionHandler: @escaping (_ res: [String: Any]?, _ error: Error?) -> Void) throws {
        let message = [
            "data": try Crypto.shared.convertToBase64(from: ciphertext)
        ]
        API.shared.signedRequest(endpoint: .volatile, method: .post, message: message, pubKey: signingPubKey, privKey: try signingPrivKey(), completionHandler: completionHandler)
    }

    private func sendByeToPersistentQueue(completionHandler: @escaping (_ res: [String: Any]?, _ error: Error?) -> Void) throws {
        let message = try JSONEncoder().encode(KeynPersistentQueueMessage(passwordSuccessfullyChanged: nil, accountID: nil, type: .end, askToLogin: nil, askToChange: nil, accounts: nil, receiptHandle: nil))
        let ciphertext = try Crypto.shared.encrypt(message, key: sharedKey())
        API.shared.signedRequest(endpoint: .persistentAppToBrowser, method: .post, message: ["data": ciphertext.base64], pubKey: signingPubKey, privKey: try signingPrivKey(), completionHandler: completionHandler)
    }

    private func sharedKey() throws -> Data {
        return try Keychain.shared.get(id: KeyIdentifier.sharedKey.identifier(for: id), service: .sharedSessionKey)
    }

    private func save(key: Data, signingKeyPair: KeyPair) throws {
        let sessionData = try PropertyListEncoder().encode(self)
        try Keychain.shared.save(id: KeyIdentifier.sharedKey.identifier(for: id), service: .sharedSessionKey, secretData: key, objectData: sessionData)
        try Keychain.shared.save(id: KeyIdentifier.signingKeyPair.identifier(for: id), service: .signingSessionKey, secretData: signingKeyPair.privKey)
    }

    private func deleteQueuesAtAWS() {
        do {
            let message = [
                "pubkey": signingPubKey
            ]
            API.shared.signedRequest(endpoint: .message, method: .delete, message: message, pubKey: nil, privKey: try signingPrivKey()) { _, error in
                if let error = error {
                    Logger.shared.error("Cannot delete endpoint at AWS.", error: error)
                }
            }
        } catch {
            Logger.shared.error("Cannot delete endpoint at AWS.", error: error)
        }
    }

    private func signingPrivKey() throws -> Data {
        return try Keychain.shared.get(id: KeyIdentifier.signingKeyPair.identifier(for: id), service: .signingSessionKey)
    }

}
