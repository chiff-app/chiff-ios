/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit
import UserNotifications
import LocalAuthentication
import PromiseKit

enum Browser: String, Codable {
    case firefox = "firefox"
    case chrome = "chrome"
    case edge = "edge"
    case safari = "safari"
    case cli = "cli"
}

/*
 * There is a non-codable part of session that is only stored in the Keychain.
 * That is: sharedKey and sigingKeyPair.privKey.
 */
struct BrowserSession: Session {
    var backgroundTask: Int = UIBackgroundTaskIdentifier.invalid.rawValue
    let browser: Browser
    let creationDate: Date
    let id: String
    let signingPubKey: String
    let version: Int
    var title: String
    var logo: UIImage? {
        return UIImage(named: browser.rawValue)
    }
    var lastRequest: Date?

    static var signingService: KeychainService = .signingSessionKey
    static var encryptionService: KeychainService = .sharedSessionKey
    static var sessionCountFlag = "sessionCount"

    init(id: String, signingPubKey: Data, browser: Browser, title: String, version: Int) {
        self.creationDate = Date()
        self.id = id
        self.signingPubKey = signingPubKey.base64
        self.browser = browser
        self.title = title
        self.version = version
    }

    func update(makeBackup: Bool = false) throws {
        let sessionData = try PropertyListEncoder().encode(self as Self)
        try Keychain.shared.update(id: SessionIdentifier.sharedKey.identifier(for: id), service: Self.encryptionService, objectData: sessionData)
    }

    func delete(notify: Bool) -> Promise<Void> {

        func deleteSession() {
            do {
                BrowserSession.count -= 1
                Logger.shared.analytics(.sessionDeleted)
                try Keychain.shared.delete(id: SessionIdentifier.sharedKey.identifier(for: id), service: .sharedSessionKey)
                try Keychain.shared.delete(id: SessionIdentifier.signingKeyPair.identifier(for: id), service: .signingSessionKey)
            } catch {
                Logger.shared.error("Error deleting session", error: error)
            }
        }
        return firstly {
            notify ? sendByeToPersistentQueue() : deleteQueuesAtAWS()
        }.map {
            deleteSession()
        }

    }

    func decrypt(message message64: String) throws -> KeynRequest {
        var message: KeynRequest = try decryptMessage(message: message64)
        message.sessionID = id
        return message
    }

    func cancelRequest(reason: KeynMessageType, browserTab: Int) -> Promise<[String: Any]> {
        do {
            let response = KeynCredentialsResponse(u: nil, p: nil, s: nil, n: nil, g: nil, np: nil, b: browserTab, a: nil, o: nil, t: reason, pk: nil, d: nil, y: nil)
            let jsonMessage = try JSONEncoder().encode(response)
            let ciphertext = try Crypto.shared.encrypt(jsonMessage, key: sharedKey())
            return try sendToVolatileQueue(ciphertext: ciphertext)
        } catch {
            return Promise(error: error)
        }
    }

    /// This sends the credentials back to the browser extension.
    ///
    /// - Parameters:
    ///   - account: The account
    ///   - browserTab: The browser tab
    ///   - type: The response type
    ///   - context: The LocalAuthenticationContext. This should already be authenticated, otherwise this function will fail
    mutating func sendCredentials(account: Account, browserTab: Int, type: KeynMessageType, context: LAContext, newPassword: String?) throws {
        var response: KeynCredentialsResponse?
        switch type {
        case .change:
            response = KeynCredentialsResponse(u: account.username, p: try account.password(context: context), s: nil, n: nil, g: nil, np: newPassword, b: browserTab, a: account.id, o: nil, t: .change, pk: nil, d: nil, y: nil)
        case .add, .addAndLogin:
            response = KeynCredentialsResponse(u: nil, p: nil, s: nil, n: nil, g: nil, np: nil, b: browserTab, a: nil, o: nil, t: type, pk: nil, d: nil, y: nil)
        case .login, .addToExisting:
            response = KeynCredentialsResponse(u: account.username, p: try account.password(context: context), s: nil, n: nil, g: nil, np: nil, b: browserTab, a: nil, o: try account.oneTimePasswordToken()?.currentPassword, t: type, pk: nil, d: nil, y: nil)
        case .getDetails:
            response = KeynCredentialsResponse(u: account.username, p: try account.password(context: context), s: nil, n: nil, g: nil, np: nil, b: browserTab, a: nil, o: try account.oneTimePasswordToken()?.currentPassword, t: type, pk: nil, d: nil, y: try account.notes(context: context))
        case .fill:
            response = KeynCredentialsResponse(u: nil, p: try account.password(context: context), s: nil, n: nil, g: nil, np: nil, b: browserTab, a: nil, o: nil, t: .fill, pk: nil, d: nil, y: nil)
        case .register:
            response = KeynCredentialsResponse(u: account.username, p: try account.password(context: context), s: nil, n: nil, g: nil, np: nil, b: browserTab, a: nil, o: nil, t: .register, pk: nil, d: nil, y: nil)
        default:
            throw SessionError.unknownType
        }

        let message = try JSONEncoder().encode(response!)
        let ciphertext = try Crypto.shared.encrypt(message, key: self.sharedKey())

        try self.sendToVolatileQueue(ciphertext: ciphertext).catchLog("Error sending credentials")
        try updateLastRequest()
    }

    // Simply acknowledge that the request is received
    mutating func sendBulkAddResponse(browserTab: Int, context: LAContext?) throws {
        let message = try JSONEncoder().encode(KeynCredentialsResponse(u: nil, p: nil, s: nil, n: nil, g: nil, np: nil, b: browserTab, a: nil, o: nil, t: .addBulk, pk: nil, d: nil, y: nil))
        let ciphertext = try Crypto.shared.encrypt(message, key: self.sharedKey())
        try self.sendToVolatileQueue(ciphertext: ciphertext).catchLog("Error sending bulk credentials")
        try updateLastRequest()
    }

    mutating func sendBulkLoginResponse(browserTab: Int, accounts: [Int: BulkLoginAccount?], context: LAContext?) throws {
        let message = try JSONEncoder().encode(KeynCredentialsResponse(u: nil, p: nil, s: nil, n: nil, g: nil, np: nil, b: browserTab, a: nil, o: nil, t: .bulkLogin, pk: nil, d: accounts, y: nil))
        let ciphertext = try Crypto.shared.encrypt(message, key: self.sharedKey())
        try self.sendToVolatileQueue(ciphertext: ciphertext).catchLog("Error sending bulk credentials")
        try updateLastRequest()
    }

    mutating func sendTeamSeed(pubkey: String, seed: String, browserTab: Int, context: LAContext) -> Promise<Void> {
        do {
            let message = try JSONEncoder().encode(KeynCredentialsResponse(u: pubkey, p: seed, s: nil, n: nil, g: nil, np: nil, b: browserTab, a: nil, o: nil, t: .adminLogin, pk: nil, d: nil, y: nil))
            let ciphertext = try Crypto.shared.encrypt(message, key: self.sharedKey())
            try self.updateLastRequest()
            return try self.sendToVolatileQueue(ciphertext: ciphertext).asVoid().log("Error sending credentials")
        } catch {
            return Promise(error: error)
        }
    }

    mutating func sendWebAuthnResponse(account: UserAccount, browserTab: Int, type: KeynMessageType, context: LAContext, signature: String?, counter: Int?) throws {
        var response: KeynCredentialsResponse!
        switch type {
        case .webauthnCreate:
            response = try KeynCredentialsResponse(u: nil, p: nil, s: signature, n: counter, g: account.webAuthn!.algorithm, np: nil, b: browserTab, a: account.id, o: nil, t: .webauthnCreate, pk: account.webAuthnPubKey(), d: nil, y: nil)
        case .webauthnLogin:
            response = KeynCredentialsResponse(u: nil, p: nil, s: signature, n: counter, g: nil, np: nil, b: browserTab, a: nil, o: nil, t: .webauthnLogin, pk: nil, d: nil, y: nil)
        default:
            throw SessionError.unknownType
        }

        let message = try JSONEncoder().encode(response)
        let ciphertext = try Crypto.shared.encrypt(message, key: self.sharedKey())

        try self.sendToVolatileQueue(ciphertext: ciphertext).catchLog("Error sending credentials")
        try updateLastRequest()
    }

    func getPersistentQueueMessages(shortPolling: Bool) -> Promise<[KeynPersistentQueueMessage]> {
        let message = [
            "waitTime": shortPolling ? "0" : "20"
        ]
        return firstly {
            API.shared.signedRequest(method: .get, message: message, path: "sessions/\(signingPubKey)/browser-to-app", privKey: try signingPrivKey(), body: nil, parameters: nil)
        }.map { result in
            guard let sqsMessages = result["messages"] as? [[String:String]] else {
               throw CodingError.missingData
            }
            return try sqsMessages.map() { message in
                guard let body = message[MessageParameter.body], let receiptHandle = message[MessageParameter.receiptHandle] else {
                    throw CodingError.missingData
                }
                var keynMessage: KeynPersistentQueueMessage = try self.decrypt(message: body)
                keynMessage.receiptHandle = receiptHandle
                return keynMessage
            }
        }
    }

    func deleteFromPersistentQueue(receiptHandle: String) -> Promise<Void> {
        let message = [
            "receiptHandle": receiptHandle
        ]
        return firstly {
            API.shared.signedRequest(method: .delete, message: message, path: "sessions/\(signingPubKey)/browser-to-app", privKey: try signingPrivKey(), body: nil, parameters: nil)
        }.asVoid().log("Failed to delete password change confirmation from queue.")
    }

    func updateSessionAccount(account: Account) throws {
        let accountData = try JSONEncoder().encode(SessionAccount(account: account))
        let ciphertext = try Crypto.shared.encrypt(accountData, key: sharedKey())
        var message = [
            "id": account.id,
            "data": ciphertext.base64
        ]
        if let SharedAccount = account as? SharedAccount {
            message["sessionPubKey"] = SharedAccount.sessionPubKey
        }
        API.shared.signedRequest(method: .put, message: message, path: "sessions/\(signingPubKey)/accounts/\(account.id)", privKey: try signingPrivKey(), body: nil, parameters: nil).catchLog("Failed to get privkey from Keychain")
    }

    func updateSessionData(organisationKey: Data?) throws -> Promise<Void> {
        var data: [String: Any] = [:]
        if let appVersion = Properties.version {
            data["appVersion"] = appVersion
        }
        if let organisationKey = organisationKey {
            data["organisationKey"] = organisationKey.base64
        }
        let message = [
            "data": try Crypto.shared.encrypt(JSONSerialization.data(withJSONObject: data, options: []), key: try sharedKey()).base64
        ]
        return API.shared.signedRequest(method: .put, message: message, path: "sessions/\(signingPubKey)", privKey: try signingPrivKey(), body: nil, parameters: nil).asVoid().log("Failed to update session data.")
    }

    func deleteAccount(accountId: String) {
        firstly {
            API.shared.signedRequest(method: .delete, message: ["id": accountId], path: "sessions/\(signingPubKey)/accounts/\(accountId)", privKey: try signingPrivKey(), body: nil, parameters: nil)
        }.catchLog("Failed to send account list to persistent queue.")
    }

    func save(key: Data, signingKeyPair: KeyPair) throws {
        let sessionData = try PropertyListEncoder().encode(self)
        try Keychain.shared.save(id: SessionIdentifier.sharedKey.identifier(for: id), service: BrowserSession.encryptionService, secretData: key, objectData: sessionData)
        try Keychain.shared.save(id: SessionIdentifier.signingKeyPair.identifier(for: id), service: BrowserSession.signingService, secretData: signingKeyPair.privKey)
    }

    func acknowledgeSessionStart(pairingKeyPair: KeyPair, browserPubKey: Data, sharedKeyPubkey: String, organisationKey: Data?) -> Promise<Void> {
        // TODO: Differentiate this for session type?
        do {
            guard let endpoint = Properties.endpoint else {
                throw SessionError.noEndpoint
            }
            let pairingResponse = KeynPairingResponse(sessionID: id, pubKey: sharedKeyPubkey, browserPubKey: browserPubKey.base64, userID: Properties.userId!, environment: Properties.environment.rawValue, accounts: try UserAccount.combinedSessionAccounts(), type: .pair, errorLogging: Properties.errorLogging, analyticsLogging: Properties.analyticsLogging, version: version, arn: endpoint, appVersion: Properties.version, organisationKey: organisationKey?.base64)
            let jsonPairingResponse = try JSONEncoder().encode(pairingResponse)
            let ciphertext = try Crypto.shared.encrypt(jsonPairingResponse, pubKey: browserPubKey)
            let signedCiphertext = try Crypto.shared.sign(message: ciphertext, privKey: pairingKeyPair.privKey)
            let message = [
                "data": signedCiphertext.base64
            ]
            let jsonData = try JSONSerialization.data(withJSONObject: message, options: [])
            return API.shared.signedRequest(method: .put, message: nil, path: "sessions/\(pairingKeyPair.pubKey.base64)/pairing", privKey: pairingKeyPair.privKey, body: jsonData, parameters: nil).log("Error sending pairing response.").asVoid()
        } catch {
            return Promise(error: error)
        }

    }


    static func initiate(pairingQueueSeed: String, browserPubKey: String, browser: Browser, os: String, version: Int = 0) -> Promise<Session> {
        do {
            let keyPairForSharedKey = try Crypto.shared.createSessionKeyPair()
            let browserPubKeyData = try Crypto.shared.convertFromBase64(from: browserPubKey)
            let sharedKey = try Crypto.shared.generateSharedKey(pubKey: browserPubKeyData, privKey: keyPairForSharedKey.privKey)
            let signingKeyPair = try Crypto.shared.createSigningKeyPair(seed: sharedKey)
            let pairingKeyPair = try Crypto.shared.createSigningKeyPair(seed: Crypto.shared.convertFromBase64(from: pairingQueueSeed))

            let session = BrowserSession(id: browserPubKey.hash, signingPubKey: signingKeyPair.pubKey, browser: browser, title: "\(browser.rawValue.capitalizedFirstLetter) @ \(os)",version: version)
            let organisationKey = try TeamSession.all().first?.organisationKey // Get first for now, perhaps handle unlikely scenario where user belongs to multiple organisation in the future.
            return firstly {
                when(fulfilled: try session.createQueues(signingKeyPair: signingKeyPair, sharedKey: sharedKey, organisationKey: organisationKey), session.acknowledgeSessionStart(pairingKeyPair: pairingKeyPair, browserPubKey: browserPubKeyData, sharedKeyPubkey: keyPairForSharedKey.pubKey.base64, organisationKey: organisationKey))
            }.map {
                do {
                    try session.save(key: sharedKey, signingKeyPair: signingKeyPair)
                    BrowserSession.count += 1
                    return session
                } catch is KeychainError {
                    throw SessionError.exists
                } catch is CryptoError {
                    throw SessionError.invalid
                }
            }
        } catch {
            Logger.shared.error("Error initiating session", error: error)
            return Promise(error: error)
        }
    }

    static func updateAllSessionData(organisationKey: Data?) {
        firstly {
            when(fulfilled: try all().map { try $0.updateSessionData(organisationKey: organisationKey) })
        }.catchLog("Failed to update session data.")
    }

    // MARK: - Private

    private func decrypt(message message64: String) throws -> KeynPersistentQueueMessage {
        // let ciphertext = try Crypto.shared.convertFromBase64(from: message64)
        // let (data, _) = try Crypto.shared.decrypt(ciphertext, key: sharedKey(), version: version)
        // return try JSONDecoder().decode(KeynPersistentQueueMessage.self, from: data)
        return try decryptMessage(message: message64)
    }


    private func createQueues(signingKeyPair keyPair: KeyPair, sharedKey: Data, organisationKey: Data?) throws -> Promise<Void>{
        guard let deviceEndpoint = Properties.endpoint else {
            throw SessionError.noEndpoint
        }
        var data: [String: Any] = [:]
        if let appVersion = Properties.version {
            data["appVersion"] = appVersion
        }
        if let organisationKey = organisationKey {
            data["organisationKey"] = organisationKey.base64
        }
        var message: [String: Any] = [
            "httpMethod": APIMethod.post.rawValue,
            "timestamp": String(Int(Date().timeIntervalSince1970)),
            "deviceEndpoint": deviceEndpoint,
            "data": try Crypto.shared.encrypt(JSONSerialization.data(withJSONObject: data, options: []), key: sharedKey).base64
        ]
        if let userId = Properties.userId {
            message["userId"] = userId
        }
        do {
            message["userAccounts"] = try UserAccount.all(context: nil).mapValues { (account) -> String in
                let accountData = try JSONEncoder().encode(SessionAccount(account: account))
                return try Crypto.shared.encrypt(accountData, key: sharedKey).base64
            }
            message["teamAccounts"] = try SharedAccount.all(context: nil).mapValues { (account) -> [String: String] in
                let accountData = try JSONEncoder().encode(SessionAccount(account: account))
                return [
                    "data": try Crypto.shared.encrypt(accountData, key: sharedKey).base64,
                    "sessionPubKey": account.sessionPubKey
                ]
            }
            let jsonData = try JSONSerialization.data(withJSONObject: message, options: [])
            let signature = try Crypto.shared.signature(message: jsonData, privKey: keyPair.privKey).base64
            return API.shared.request(path: "sessions/\(keyPair.pubKey.base64)", parameters: nil, method: .post, signature: signature, body: jsonData).asVoid().log("Cannot create SQS queues and SNS endpoint.")
        } catch {
            return Promise(error: error)
        }
    }

    private func sendToVolatileQueue(ciphertext: Data) throws -> Promise<[String: Any]> {
        let message = [
            "data": try Crypto.shared.convertToBase64(from: ciphertext)
        ]
        return API.shared.signedRequest( method: .put, message: message, path: "sessions/\(signingPubKey)/volatile", privKey: try signingPrivKey(), body: nil, parameters: nil)
    }

    private func sendByeToPersistentQueue() -> Promise<Void> {
        do {
            let message = try JSONEncoder().encode(KeynPersistentQueueMessage(passwordSuccessfullyChanged: nil, accountID: nil, type: .end, askToLogin: nil, askToChange: nil, accounts: nil, receiptHandle: nil))
            let ciphertext = try Crypto.shared.encrypt(message, key: sharedKey())
            return API.shared.signedRequest(method: .put, message: ["data": ciphertext.base64], path: "sessions/\(signingPubKey)/app-to-browser", privKey: try signingPrivKey(), body: nil, parameters: nil).asVoid().log("Failed to send bye to persistent queue.")
        } catch {
            return Promise(error: error)
        }
    }

    private mutating func updateLastRequest() throws {
        lastRequest = Date()
        try update()
        NotificationCenter.default.postMain(name: .sessionUpdated, object: nil, userInfo: ["session": self])
    }
}

extension BrowserSession: Codable {

    enum CodingKeys: CodingKey {
          case backgroundTask
          case browser
          case creationDate
          case id
          case signingPubKey
          case version
          case title
          case lastRequest
      }

      enum LegacyCodingKey: CodingKey {
          case os
      }

      init(from decoder: Decoder) throws {
          let values = try decoder.container(keyedBy: CodingKeys.self)
          self.id = try values.decode(String.self, forKey: .id)
          self.title = try values.decodeIfPresent(String.self, forKey: .title) ?? ""
          self.signingPubKey = try values.decode(String.self, forKey: .signingPubKey)
          self.backgroundTask = UIBackgroundTaskIdentifier.invalid.rawValue
          self.creationDate = try values.decode(Date.self, forKey: .creationDate)
          self.version = try values.decodeIfPresent(Int.self, forKey: .version) ?? 0
          self.lastRequest = try values.decodeIfPresent(Date.self, forKey: .lastRequest)
          let browser = try values.decode(Browser.self, forKey: .browser)
          self.browser = browser
          if let title = try values.decodeIfPresent(String.self, forKey: .title) {
              self.title = title
          } else {
              let legacyValues = try decoder.container(keyedBy: LegacyCodingKey.self)
              if let os = try legacyValues.decodeIfPresent(String.self, forKey: .os) {
                  self.title = "\(browser.rawValue) on \(os)"
              } else {
                  self.title = browser.rawValue
              }
          }
      }
}
