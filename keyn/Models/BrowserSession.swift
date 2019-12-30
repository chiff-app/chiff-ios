/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit
import UserNotifications
import LocalAuthentication

/*
 * There is a non-codable part of session that is only stored in the Keychain.
 * That is: sharedKey and sigingKeyPair.privKey.
 */
class BrowserSession: Session {

    var backgroundTask: Int = UIBackgroundTaskIdentifier.invalid.rawValue
    let browser: String
    let creationDate: Date
    let id: String
    let os: String
    let signingPubKey: String
    let version: Int
    var title: String {
        return "\(browser) on \(os)" // TODO: Localize
    }
    var logo: UIImage? {
        return UIImage(named: browser.lowercased())
    }
    static var signingService: KeychainService = .signingSessionKey
    static var encryptionService: KeychainService = .sharedSessionKey
    static var sessionCountFlag = "sessionCount"

    enum CodingKeys: CodingKey {
        case backgroundTask
        case browser
        case creationDate
        case id
        case os
        case signingPubKey
        case version
    }

    required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try values.decode(String.self, forKey: .id)
        self.browser = try values.decode(String.self, forKey: .browser)
        self.os = try values.decode(String.self, forKey: .os)
        self.signingPubKey = try values.decode(String.self, forKey: .signingPubKey)
        self.backgroundTask = UIBackgroundTaskIdentifier.invalid.rawValue
        self.creationDate = try values.decode(Date.self, forKey: .creationDate)
        self.version = try values.decodeIfPresent(Int.self, forKey: .version) ?? 0
    }

    init(id: String, signingPubKey: Data, browser: String, os: String, version: Int) {
        self.creationDate = Date()
        self.id = id
        self.signingPubKey = signingPubKey.base64
        self.browser = browser
        self.os = os
        self.version = version
    }

    func delete(notify: Bool) throws {
        BrowserSession.count -= 1
        Logger.shared.analytics(.sessionDeleted)
        if notify {
            try sendByeToPersistentQueue() { (result) in
                if case let .failure(error) = result {
                     Logger.shared.error("Error sending bye to persistent queue.", error: error)
                }
            }
        } else { // App should delete the queues
            deleteQueuesAtAWS()
        }
        try Keychain.shared.delete(id: SessionIdentifier.sharedKey.identifier(for: id), service: .sharedSessionKey)
        try Keychain.shared.delete(id: SessionIdentifier.signingKeyPair.identifier(for: id), service: .signingSessionKey)
    }

    func decrypt(message message64: String) throws -> KeynRequest {
        var message: KeynRequest = try decryptMessage(message: message64)
        message.sessionID = id
        return message
    }

    func cancelRequest(reason: KeynMessageType, browserTab: Int, completionHandler: @escaping (Result<[String: Any], Error>) -> Void) {
        do {
            let response = KeynCredentialsResponse(u: nil, p: nil, np: nil, b: browserTab, a: nil, o: nil, t: reason)
            let jsonMessage = try JSONEncoder().encode(response)
            let ciphertext = try Crypto.shared.encrypt(jsonMessage, key: sharedKey())
            try sendToVolatileQueue(ciphertext: ciphertext, completionHandler: completionHandler)
        } catch {
            completionHandler(.failure(error))
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
        var response: KeynCredentialsResponse?
        switch type {
        case .change:
            guard var account = account as? UserAccount else {
                throw SessionError.unknownType
            }
            response = KeynCredentialsResponse(u: account.username, p: try account.password(context: context), np: try account.nextPassword(context: context), b: browserTab, a: account.id, o: nil, t: .change)
            NotificationCenter.default.post(name: .passwordChangeConfirmation, object: self, userInfo: ["context": context])
        case .add, .addAndLogin, .addToExisting:
            response = KeynCredentialsResponse(u: nil, p: nil, np: nil, b: browserTab, a: nil, o: nil, t: type)
        case .login:
            response = KeynCredentialsResponse(u: account.username, p: try account.password(context: context), np: nil, b: browserTab, a: nil, o: try account.oneTimePasswordToken()?.currentPassword, t: .login)
        case .fill:
            response = KeynCredentialsResponse(u: nil, p: try account.password(context: context), np: nil, b: browserTab, a: nil, o: nil, t: .fill)
        case .register:
            response = KeynCredentialsResponse(u: account.username, p: try account.password(context: context), np: nil, b: browserTab, a: nil, o: nil, t: .register)
        default:
            throw SessionError.unknownType
        }

        let message = try JSONEncoder().encode(response!)
        let ciphertext = try Crypto.shared.encrypt(message, key: self.sharedKey())

        try self.sendToVolatileQueue(ciphertext: ciphertext) { (result) in
            if case let .failure(error) = result {
                Logger.shared.error("Error sending credentials", error: error)
            }
        }
    }

    func getPersistentQueueMessages(shortPolling: Bool, completionHandler: @escaping (Result<[KeynPersistentQueueMessage], Error>) -> Void) {
        let message = [
            "waitTime": shortPolling ? "0" : "20"
        ]
        do {
            API.shared.signedRequest(method: .get, message: message, path: "sessions/\(signingPubKey)/browser-to-app", privKey: try signingPrivKey(), body: nil) { result in
                completionHandler(Result(catching: {
                    guard let sqsMessages = try result.get()["messages"] as? [[String:String]] else {
                        throw CodingError.missingData
                    }
                    return try sqsMessages.map({ (message) -> KeynPersistentQueueMessage in
                        guard let body = message[MessageParameter.body], let receiptHandle = message[MessageParameter.receiptHandle] else {
                            throw CodingError.missingData
                        }
                        var keynMessage: KeynPersistentQueueMessage = try self.decrypt(message: body)
                        keynMessage.receiptHandle = receiptHandle
                        return keynMessage
                    })
                }))
            }
        } catch {
            completionHandler(.failure(error))
        }
    }

    func deleteFromPersistentQueue(receiptHandle: String) {
        let message = [
            "receiptHandle": receiptHandle
        ]
        do {
            API.shared.signedRequest(method: .delete, message: message, path: "sessions/\(signingPubKey)/browser-to-app", privKey: try signingPrivKey(), body: nil) { result in
                if case let .failure(error) = result {
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
        API.shared.signedRequest(method: .put, message: message, path: "sessions/\(signingPubKey)/accounts/\(account.id)", privKey: try signingPrivKey(), body: nil) { result in
            if case let .failure(error) = result {
                Logger.shared.warning("Failed to send account list to persistent queue.", error: error)
            }
        }
    }

    func deleteAccount(accountId: String) {
        do {
            API.shared.signedRequest(method: .delete, message: ["id": accountId], path: "sessions/\(signingPubKey)/accounts/\(accountId)", privKey: try signingPrivKey(), body: nil) { result in
                if case let .failure(error) = result {
                    Logger.shared.warning("Failed to send account list to persistent queue.", error: error)
                }
            }
        } catch {
            Logger.shared.warning("Failed to signing privkey from Keychain", error: error)
        }
    }

    func save(key: Data, signingKeyPair: KeyPair) throws {
        let sessionData = try PropertyListEncoder().encode(self)
        try Keychain.shared.save(id: SessionIdentifier.sharedKey.identifier(for: id), service: BrowserSession.encryptionService, secretData: key, objectData: sessionData)
        try Keychain.shared.save(id: SessionIdentifier.signingKeyPair.identifier(for: id), service: BrowserSession.signingService, secretData: signingKeyPair.privKey)
    }

    func acknowledgeSessionStart(pairingKeyPair: KeyPair, browserPubKey: Data, sharedKeyPubkey: String, completion: @escaping (Result<Void, Error>) -> Void) throws {
        // TODO: Differentiate this for session type?
        let pairingResponse = KeynPairingResponse(sessionID: id, pubKey: sharedKeyPubkey, browserPubKey: browserPubKey.base64, userID: Properties.userId!, environment: Properties.environment.rawValue, accounts: try UserAccount.accountList(), type: .pair, errorLogging: Properties.errorLogging, analyticsLogging: Properties.analyticsLogging, version: version)
        let jsonPairingResponse = try JSONEncoder().encode(pairingResponse)
        let ciphertext = try Crypto.shared.encrypt(jsonPairingResponse, pubKey: browserPubKey)
        let signedCiphertext = try Crypto.shared.sign(message: ciphertext, privKey: pairingKeyPair.privKey)
        let message = [
            "data": signedCiphertext.base64
        ]
        let jsonData = try JSONSerialization.data(withJSONObject: message, options: [])
        API.shared.signedRequest(method: .put, message: nil, path: "sessions/\(pairingKeyPair.pubKey.base64)/pairing", privKey: pairingKeyPair.privKey, body: jsonData) { result in
            if case let .failure(error) = result {
                Logger.shared.error("Error sending pairing response.", error: error)
            } else {
                completion(.success(()))
            }
        }
    }


    static func initiate(pairingQueueSeed: String, browserPubKey: String, browser: String, os: String, version: Int = 0, completionHandler: @escaping (Result<Session, Error>) -> Void) {
        do {
            let keyPairForSharedKey = try Crypto.shared.createSessionKeyPair()
            let browserPubKeyData = try Crypto.shared.convertFromBase64(from: browserPubKey)
            let sharedKey = try Crypto.shared.generateSharedKey(pubKey: browserPubKeyData, privKey: keyPairForSharedKey.privKey)
            let signingKeyPair = try Crypto.shared.createSigningKeyPair(seed: sharedKey)

            let pairingKeyPair = try Crypto.shared.createSigningKeyPair(seed: Crypto.shared.convertFromBase64(from: pairingQueueSeed))

            let session = BrowserSession(id: browserPubKey.hash, signingPubKey: signingKeyPair.pubKey, browser: browser, os: os, version: version)
            let group = DispatchGroup()
            var groupError: Error?
            group.enter()
            try session.createQueues(signingKeyPair: signingKeyPair, sharedKey: sharedKey) { result in
                if groupError == nil {
                    if case let .failure(error) = result {
                        groupError = error
                    }
                }
                group.leave()
            }
            group.enter()
            try session.acknowledgeSessionStart(pairingKeyPair: pairingKeyPair, browserPubKey: browserPubKeyData, sharedKeyPubkey: keyPairForSharedKey.pubKey.base64)  { result in
                if groupError == nil {
                    if case let .failure(error) = result {
                        groupError = error
                    }
                }
                group.leave()
            }
            group.notify(queue: .main) {
                do {
                    if let error = groupError {
                        throw error
                    }
                    try session.save(key: sharedKey, signingKeyPair: signingKeyPair)
                    BrowserSession.count += 1
                    completionHandler(.success(session))
                } catch is KeychainError {
                    completionHandler(.failure(SessionError.exists))
                } catch is CryptoError {
                    completionHandler(.failure(SessionError.invalid))
                } catch {
                    completionHandler(.failure(error))
                }
            }
        } catch {
            Logger.shared.error("Error initiating session", error: error)
            completionHandler(.failure(error))
        }
    }

    // MARK: - Private

    private func decrypt(message message64: String) throws -> KeynPersistentQueueMessage {
        // let ciphertext = try Crypto.shared.convertFromBase64(from: message64)
        // let (data, _) = try Crypto.shared.decrypt(ciphertext, key: sharedKey(), version: version)
        // return try JSONDecoder().decode(KeynPersistentQueueMessage.self, from: data)
        return try decryptMessage(message: message64)
    }


    private func createQueues(signingKeyPair keyPair: KeyPair, sharedKey: Data, completionHandler: @escaping (Result<Void, Error>) -> Void) throws {
        guard let deviceEndpoint = Properties.endpoint else {
            throw SessionError.noEndpoint
        }

        var message: [String: Any] = [
            "httpMethod": APIMethod.put.rawValue,
            "timestamp": String(Int(Date().timeIntervalSince1970)),
            "deviceEndpoint": deviceEndpoint
        ]
        if let userId = Properties.userId {
            message["userId"] = userId
        }

        do {
            let encryptedAccounts = try UserAccount.accountList().mapValues { (account) -> String in
                let accountData = try JSONEncoder().encode(account)
                return try Crypto.shared.encrypt(accountData, key: sharedKey).base64
            }
            message["accountList"] = encryptedAccounts
            let jsonData = try JSONSerialization.data(withJSONObject: message, options: [])
            let signature = try Crypto.shared.signature(message: jsonData, privKey: keyPair.privKey).base64
            API.shared.request(path: "sessions/\(keyPair.pubKey.base64)", parameters: nil, method: .put, signature: signature, body: jsonData) { (result) in
                switch result {
                case .success(_): completionHandler(.success(()))
                case .failure(let error):
                    Logger.shared.error("Cannot create SQS queues and SNS endpoint.", error: error)
                    completionHandler(.failure(error))
                }
            }
        } catch {
            completionHandler(.failure(error))
        }
    }

    private func sendToVolatileQueue(ciphertext: Data, completionHandler: @escaping (Result<[String: Any], Error>) -> Void) throws {
        let message = [
            "data": try Crypto.shared.convertToBase64(from: ciphertext)
        ]
        API.shared.signedRequest( method: .put, message: message, path: "session/\(signingPubKey)/volatile", privKey: try signingPrivKey(), body: nil, completionHandler: completionHandler)
    }

    private func sendByeToPersistentQueue(completionHandler: @escaping (Result<[String: Any], Error>) -> Void) throws {
        let message = try JSONEncoder().encode(KeynPersistentQueueMessage(passwordSuccessfullyChanged: nil, accountID: nil, type: .end, askToLogin: nil, askToChange: nil, accounts: nil, receiptHandle: nil))
        let ciphertext = try Crypto.shared.encrypt(message, key: sharedKey())
        API.shared.signedRequest(method: .put, message: ["data": ciphertext.base64], path: "session/\(signingPubKey)/app-to-browser", privKey: try signingPrivKey(), body: nil, completionHandler: completionHandler)
    }

    //     private func save(key: Data, signingKeyPair: KeyPair) throws {
    //     let sessionData = try PropertyListEncoder().encode(self)
    //     try Keychain.shared.save(id: SessionIdentifier.sharedKey.identifier(for: id), service: .sharedSessionKey, secretData: key, objectData: sessionData)
    //     try Keychain.shared.save(id: SessionIdentifier.signingKeyPair.identifier(for: id), service: .signingSessionKey, secretData: signingKeyPair.privKey)
    // }

    // private func deleteQueuesAtAWS() {
    //     do {
    //         let message = [
    //             "pubkey": signingPubKey
    //         ]
    //         API.shared.signedRequest(endpoint: .message, method: .delete, message: message, pubKey: nil, privKey: try signingPrivKey(), body: nil) { (result) in
    //             if case let .failure(error) = result {
    //                 Logger.shared.error("Cannot delete endpoint at AWS.", error: error)
    //             }
    //         }
    //     } catch {
    //         Logger.shared.error("Cannot delete endpoint at AWS.", error: error)
    //     }
    // }

    // private func signingPrivKey() throws -> Data {
    //     return try Keychain.shared.get(id: SessionIdentifier.signingKeyPair.identifier(for: id), service: .signingSessionKey)
    // }
}
