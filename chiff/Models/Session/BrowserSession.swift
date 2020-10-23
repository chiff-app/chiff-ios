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
    case brave = "brave"
    case opera = "opera"
}

/*
 * There is a non-codable part of session that is only stored in the Keychain.
 * That is: sharedKey and sigingKeyPair.privKey.
 */
struct BrowserSession: Session {
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
            let response = KeynCredentialsResponse(username: nil, password: nil, signature: nil, counter: nil, algorithm: nil, newPassword: nil, browserTab: browserTab, accountId: nil, otp: nil, type: reason, pubKey: nil, accounts: nil, notes: nil, teamId: nil)
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
            response = KeynCredentialsResponse(username: account.username, password: try account.password(context: context), signature: nil, counter: nil, algorithm: nil, newPassword: newPassword, browserTab: browserTab, accountId: account.id, otp: nil, type: .change, pubKey: nil, accounts: nil, notes: nil, teamId: nil)
        case .add, .addAndLogin, .updateAccount:
            response = KeynCredentialsResponse(username: nil, password: nil, signature: nil, counter: nil, algorithm: nil, newPassword: nil, browserTab: browserTab, accountId: nil, otp: nil, type: type, pubKey: nil, accounts: nil, notes: nil, teamId: nil)
        case .login, .addToExisting:
            response = KeynCredentialsResponse(username: account.username, password: try account.password(context: context), signature: nil, counter: nil, algorithm: nil, newPassword: nil, browserTab: browserTab, accountId: nil, otp: try account.oneTimePasswordToken()?.currentPassword, type: type, pubKey: nil, accounts: nil, notes: nil, teamId: nil)
        case .getDetails:
            response = KeynCredentialsResponse(username: account.username, password: try account.password(context: context), signature: nil, counter: nil, algorithm: nil, newPassword: nil, browserTab: browserTab, accountId: nil, otp: try account.oneTimePasswordToken()?.currentPassword, type: type, pubKey: nil, accounts: nil, notes: try account.notes(context: context), teamId: nil)
        case .fill:
            response = KeynCredentialsResponse(username: nil, password: try account.password(context: context), signature: nil, counter: nil, algorithm: nil, newPassword: nil, browserTab: browserTab, accountId: nil, otp: nil, type: .fill, pubKey: nil, accounts: nil, notes: nil, teamId: nil)
        case .register:
            response = KeynCredentialsResponse(username: account.username, password: try account.password(context: context), signature: nil, counter: nil, algorithm: nil, newPassword: nil, browserTab: browserTab, accountId: nil, otp: nil, type: .register, pubKey: nil, accounts: nil, notes: nil, teamId: nil)
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
        let message = try JSONEncoder().encode(KeynCredentialsResponse(username: nil, password: nil, signature: nil, counter: nil, algorithm: nil, newPassword: nil, browserTab: browserTab, accountId: nil, otp: nil, type: .addBulk, pubKey: nil, accounts: nil, notes: nil, teamId: nil))
        let ciphertext = try Crypto.shared.encrypt(message, key: self.sharedKey())
        try self.sendToVolatileQueue(ciphertext: ciphertext).catchLog("Error sending bulk credentials")
        try updateLastRequest()
    }

    mutating func sendBulkLoginResponse(browserTab: Int, accounts: [Int: BulkLoginAccount?], context: LAContext?) throws {
        let message = try JSONEncoder().encode(KeynCredentialsResponse(username: nil, password: nil, signature: nil, counter: nil, algorithm: nil, newPassword: nil, browserTab: browserTab, accountId: nil, otp: nil, type: .bulkLogin, pubKey: nil, accounts: accounts, notes: nil, teamId: nil))
        let ciphertext = try Crypto.shared.encrypt(message, key: self.sharedKey())
        try self.sendToVolatileQueue(ciphertext: ciphertext).catchLog("Error sending bulk credentials")
        try updateLastRequest()
    }

    mutating func sendTeamSeed(id: String, teamId: String, seed: String, browserTab: Int, context: LAContext, organisationKey: String?) -> Promise<Void> {
        do {
            let message = try JSONEncoder().encode(KeynCredentialsResponse(username: id, password: seed, signature: nil, counter: nil, algorithm: nil, newPassword: nil, browserTab: browserTab, accountId: nil, otp: organisationKey, type: .createOrganisation, pubKey: nil, accounts: nil, notes: nil, teamId: teamId))
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
            response = try KeynCredentialsResponse(username: nil, password: nil, signature: signature, counter: counter, algorithm: account.webAuthn!.algorithm, newPassword: nil, browserTab: browserTab, accountId: account.id, otp: nil, type: .webauthnCreate, pubKey: account.webAuthnPubKey(), accounts: nil, notes: nil, teamId: nil)
        case .webauthnLogin:
            response = KeynCredentialsResponse(username: nil, password: nil, signature: signature, counter: counter, algorithm: nil, newPassword: nil, browserTab: browserTab, accountId: nil, otp: nil, type: .webauthnLogin, pubKey: nil, accounts: nil, notes: nil, teamId: nil)
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
            API.shared.signedRequest(path: "sessions/\(signingPubKey)/browser-to-app", method: .get, privKey: try signingPrivKey(), message: message)
        }.map { result in
            guard let sqsMessages = result["messages"] as? [[String: String]] else {
               throw CodingError.missingData
            }
            return try sqsMessages.map { message in
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
            API.shared.signedRequest(path: "sessions/\(signingPubKey)/browser-to-app", method: .delete, privKey: try signingPrivKey(), message: message)
        }.asVoid().log("Failed to delete password change confirmation from queue.")
    }

    func updateSessionAccount(account: Account) throws {
        let accountData = try JSONEncoder().encode(SessionAccount(account: account))
        let ciphertext = try Crypto.shared.encrypt(accountData, key: sharedKey())
        let message = [
            "id": account.id,
            "data": ciphertext.base64
        ]
        API.shared.signedRequest(path: "sessions/\(signingPubKey)/accounts/\(account.id)", method: .put, privKey: try signingPrivKey(), message: message).catchLog("Failed to get privkey from Keychain")
    }

    func updateSessionAccounts(accounts: [String: UserAccount]) -> Promise<Void> {
        do {
            let encryptedAccounts: [String: String] = try accounts.mapValues {
                let data = try JSONEncoder().encode(SessionAccount(account: $0))
                return try Crypto.shared.encrypt(data, key: sharedKey()).base64
            }
            let message: [String: Any] = [
                "httpMethod": APIMethod.put.rawValue,
                "timestamp": String(Date.now),
                "accounts": encryptedAccounts
            ]
            let jsonData = try JSONSerialization.data(withJSONObject: message, options: [])
            let signature = try Crypto.shared.signature(message: jsonData, privKey: try signingPrivKey()).base64
            return firstly {
                API.shared.request(path: "sessions/\(signingPubKey)/accounts", method: .put, signature: signature, body: jsonData)
            }.asVoid().log("Session cannot write bulk session accounts.")
        } catch {
            return Promise(error: error)
        }
    }

    func updateSessionData(organisationKey: Data?, organisationType: OrganisationType?, isAdmin: Bool) throws -> Promise<Void> {
        let message = [
            "data": try encryptSessionData(organisationKey: organisationKey, organisationType: organisationType, isAdmin: isAdmin)
        ]
        return API.shared.signedRequest(path: "sessions/\(signingPubKey)", method: .put,  privKey: try signingPrivKey(), message: message).asVoid().log("Failed to update session data.")
    }

    func encryptSessionData(organisationKey: Data?, organisationType: OrganisationType?, isAdmin: Bool, migrated: Bool? = nil) throws -> String {
        var data: [String: Any] = [
            "environment": (migrated ?? Properties.migrated) ? Properties.Environment.prod.rawValue : Properties.environment.rawValue,
            "isAdmin": isAdmin
        ]
        if let appVersion = Properties.version {
            data["appVersion"] = appVersion
        }
        if let organisationKey = organisationKey {
            data["organisationKey"] = organisationKey.base64
        }
        if let organisationType = organisationType {
            data["organisationType"] = organisationType.rawValue
        }
        return try Crypto.shared.encrypt(JSONSerialization.data(withJSONObject: data, options: []), key: try sharedKey()).base64
    }

    func deleteAccount(accountId: String) {
        firstly {
            API.shared.signedRequest(path: "sessions/\(signingPubKey)/accounts/\(accountId)", method: .delete, privKey: try signingPrivKey(), message: ["id": accountId])
        }.catchLog("Failed to send account list to persistent queue.")
    }

    func save(key: Data, signingKeyPair: KeyPair) throws {
        let sessionData = try PropertyListEncoder().encode(self)
        try Keychain.shared.save(id: SessionIdentifier.sharedKey.identifier(for: id), service: BrowserSession.encryptionService, secretData: key, objectData: sessionData)
        try Keychain.shared.save(id: SessionIdentifier.signingKeyPair.identifier(for: id), service: BrowserSession.signingService, secretData: signingKeyPair.privKey)
    }

    func acknowledgeSessionStart(pairingKeyPair: KeyPair, browserPubKey: Data, sharedKeyPubkey: String, isAdmin: Bool?, organisationKey: Data?, organisationType: OrganisationType?) -> Promise<Void> {
        // TODO: Differentiate this for session type?
        do {
            guard let endpoint = Properties.endpoint else {
                throw SessionError.noEndpoint
            }
            let pairingResponse = KeynPairingResponse(sessionID: id, pubKey: sharedKeyPubkey, browserPubKey: browserPubKey.base64, userID: Properties.userId!, environment: Properties.migrated ? Properties.Environment.prod.rawValue : Properties.environment.rawValue, accounts: try UserAccount.combinedSessionAccounts(), type: .pair, errorLogging: Properties.errorLogging, analyticsLogging: Properties.analyticsLogging, version: version, arn: endpoint, appVersion: Properties.version, organisationKey: organisationKey?.base64, organisationType: organisationType, isAdmin: isAdmin)
            let jsonPairingResponse = try JSONEncoder().encode(pairingResponse)
            let ciphertext = try Crypto.shared.encrypt(jsonPairingResponse, pubKey: browserPubKey)
            let signedCiphertext = try Crypto.shared.sign(message: ciphertext, privKey: pairingKeyPair.privKey)
            let message = [
                "data": signedCiphertext.base64
            ]
            let jsonData = try JSONSerialization.data(withJSONObject: message, options: [])
            return API.shared.signedRequest(path: "sessions/\(pairingKeyPair.pubKey.base64)/pairing", method: .put, privKey: pairingKeyPair.privKey, message: nil, body: jsonData).log("Error sending pairing response.").asVoid()
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

            let session = BrowserSession(id: browserPubKey.hash, signingPubKey: signingKeyPair.pubKey, browser: browser, title: "\(browser.rawValue.capitalizedFirstLetter) @ \(os)", version: version)
            let teamSession = try TeamSession.all().first // Get first for now, perhaps handle unlikely scenario where user belongs to multiple organisation in the future.
            return firstly {
                try session.createQueues(signingKeyPair: signingKeyPair, sharedKey: sharedKey, isAdmin: teamSession?.isAdmin, organisationKey: teamSession?.organisationKey, organisationType: teamSession?.type)
            }.then {
                session.acknowledgeSessionStart(pairingKeyPair: pairingKeyPair, browserPubKey: browserPubKeyData, sharedKeyPubkey: keyPairForSharedKey.pubKey.base64, isAdmin: teamSession?.isAdmin, organisationKey: teamSession?.organisationKey, organisationType: teamSession?.type)
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

    static func updateAllSessionData(organisationKey: Data?, organisationType: OrganisationType?, isAdmin: Bool) {
        firstly {
            when(fulfilled: try all().map { try $0.updateSessionData(organisationKey: organisationKey, organisationType: organisationType, isAdmin: isAdmin) })
        }.catchLog("Failed to update session data.")
    }

    // MARK: - Private

    private func decrypt(message message64: String) throws -> KeynPersistentQueueMessage {
        return try decryptMessage(message: message64)
    }

    private func createQueues(signingKeyPair keyPair: KeyPair, sharedKey: Data, isAdmin: Bool?, organisationKey: Data?, organisationType: OrganisationType?) throws -> Promise<Void> {
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
        if let organisationType = organisationType {
            data["organisationType"] = organisationType.rawValue
        }
        if let isAdmin = isAdmin {
            data["isAdmin"] = isAdmin
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
            let userAccounts = try UserAccount.all(context: nil)
            message["userAccounts"] = try userAccounts.mapValues { (account) -> String in
                let accountData = try JSONEncoder().encode(SessionAccount(account: account))
                return try Crypto.shared.encrypt(accountData, key: sharedKey).base64
            }
            message["teamAccounts"] = try SharedAccount.all(context: nil).compactMapValues { (account) -> [String: String]? in
                guard !userAccounts.keys.contains(account.id) else {
                    return nil
                }
                let accountData = try JSONEncoder().encode(SessionAccount(account: account))
                return [
                    "data": try Crypto.shared.encrypt(accountData, key: sharedKey).base64,
                    "sessionId": account.sessionId
                ]
            }
            let jsonData = try JSONSerialization.data(withJSONObject: message, options: [])
            let signature = try Crypto.shared.signature(message: jsonData, privKey: keyPair.privKey).base64
            return API.shared.request(path: "sessions/\(keyPair.pubKey.base64)", method: .post, signature: signature, body: jsonData).asVoid().log("Cannot create SQS queues and SNS endpoint.")
        } catch {
            return Promise(error: error)
        }
    }

    private func sendToVolatileQueue(ciphertext: Data) throws -> Promise<[String: Any]> {
        let message = [
            "data": try Crypto.shared.convertToBase64(from: ciphertext)
        ]
        return API.shared.signedRequest(path: "sessions/\(signingPubKey)/volatile", method: .put, privKey: try signingPrivKey(), message: message)
    }

    private func sendByeToPersistentQueue() -> Promise<Void> {
        do {
            let message = try JSONEncoder().encode(KeynPersistentQueueMessage(passwordSuccessfullyChanged: nil, accountID: nil, type: .end, askToLogin: nil, askToChange: nil, accounts: nil, receiptHandle: nil))
            let ciphertext = try Crypto.shared.encrypt(message, key: sharedKey())
            return API.shared.signedRequest(path: "sessions/\(signingPubKey)/app-to-browser", method: .put, privKey: try signingPrivKey(), message: ["data": ciphertext.base64]).asVoid().log("Failed to send bye to persistent queue.")
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
        self.creationDate = try values.decode(Date.self, forKey: .creationDate)
        self.version = try values.decodeIfPresent(Int.self, forKey: .version) ?? 0
        self.lastRequest = try values.decodeIfPresent(Date.self, forKey: .lastRequest)
        do {
            let browser = try values.decode(Browser.self, forKey: .browser)
            self.browser = browser
        } catch {
            guard let browser = try Browser(rawValue: values.decode(String.self, forKey: .browser).lowercased()) else {
                throw error
            }
            self.browser = browser
        }
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
