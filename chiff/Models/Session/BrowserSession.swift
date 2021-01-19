//
//  BrowserSession.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import UIKit
import UserNotifications
import LocalAuthentication
import PromiseKit

enum Browser: String, Codable {
    case firefox
    case chrome
    case edge
    case safari
    case cli
    case brave
    case opera
}

/// The session with a browser. Can actually also be with CLI.
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

    static var signingService: KeychainService = .browserSession(attribute: .signing)
    static var encryptionService: KeychainService = .browserSession(attribute: .shared)
    static var sessionCountFlag = "sessionCount"

    /// Initiate a BrowserSession.
    /// - Parameters:
    ///   - id: The session ID.
    ///   - signingPubKey: The session signing pubkey.
    ///   - browser: The type of browser.
    ///   - title: The session title. Just used internally.
    ///   - version: The session version.
    init(id: String, signingPubKey: Data, browser: Browser, title: String, version: Int) {
        self.creationDate = Date()
        self.id = id
        self.signingPubKey = signingPubKey.base64
        self.browser = browser
        self.title = title
        self.version = version
    }

    // Documentation in protocol
    func update(makeBackup: Bool = false) throws {
        let sessionData = try PropertyListEncoder().encode(self as Self)
        try Keychain.shared.update(id: SessionIdentifier.sharedKey.identifier(for: id), service: Self.encryptionService, objectData: sessionData)
    }

    // Documentation in protocol
    func delete(notify: Bool) -> Promise<Void> {

        func deleteSession() {
            do {
                BrowserSession.count -= 1
                Logger.shared.analytics(.sessionDeleted)
                try Keychain.shared.delete(id: SessionIdentifier.sharedKey.identifier(for: id), service: Self.encryptionService)
                try Keychain.shared.delete(id: SessionIdentifier.signingKeyPair.identifier(for: id), service: Self.signingService)
            } catch {
                Logger.shared.error("Error deleting session", error: error)
            }
        }
        return firstly {
            notify ? sendByeToPersistentQueue() : deleteQueues()
        }.map {
            deleteSession()
        }

    }

    /// Decrypt a message into a `ChiffRequest`.
    /// - Parameter message64: The base64-encoded cihertext.
    /// - Throws: Decryption, decoding or Keychain errors.
    /// - Returns: The `ChiffRequest`.
    func decrypt(message message64: String) throws -> ChiffRequest {
        var message: ChiffRequest = try decryptMessage(message: message64)
        message.sessionID = id
        return message
    }

    /// Send a simple message to the client that the request was cancelled.
    /// - Parameters:
    ///   - reason: The cancellation reason.
    ///   - browserTab: The browserTab in the client.
    func cancelRequest(reason: ChiffMessageType, browserTab: Int) -> Promise<Void> {
        do {
            let response = KeynCredentialsResponse(type: reason, browserTab: browserTab)
            let jsonMessage = try JSONEncoder().encode(response)
            let ciphertext = try Crypto.shared.encrypt(jsonMessage, key: sharedKey())
            return try sendToVolatileQueue(ciphertext: ciphertext).asVoid()
        } catch {
            return Promise(error: error)
        }
    }

    /// This responds to a request accordingly.
    /// - Parameters:
    ///   - account: The account
    ///   - browserTab: The browser tab
    ///   - type: The response type
    ///   - context: The LocalAuthenticationContext. This should already be authenticated, otherwise this function will fail
    mutating func sendCredentials(account: Account, browserTab: Int, type: ChiffMessageType, context: LAContext, newPassword: String?) throws {
        var response: KeynCredentialsResponse = KeynCredentialsResponse(type: type, browserTab: browserTab)
        switch type {
        case .getDetails:
            response.notes = try account.notes(context: context)
            fallthrough
        case .login, .addToExisting:
            response.otp = try account.oneTimePasswordToken()?.currentPassword
            fallthrough
        case .register:
            response.username = account.username
            fallthrough
        case .fill:
            response.password = try account.password(context: context)
        case .change:
            response.accountId = account.id
            response.username = account.username
            response.password = try account.password(context: context)
            response.newPassword = newPassword
        case .add, .addAndLogin, .updateAccount:
            break
        default:
            throw SessionError.unknownType
        }

        let message = try JSONEncoder().encode(response)
        let ciphertext = try Crypto.shared.encrypt(message, key: self.sharedKey())

        try self.sendToVolatileQueue(ciphertext: ciphertext).catchLog("Error sending credentials")
        try updateLastRequest()
    }

    /// Respond the a request to add multiple acounts. Simply acknowledges that the request is received
    /// - Parameters:
    ///   - browserTab: The browser tab in the client.
    ///   - context: Optionally, an authenticated `LAContext` object.
    /// - Throws: Encoding, encryption or network errors.
    mutating func sendBulkAddResponse(browserTab: Int, context: LAContext?) throws {
        let message = try JSONEncoder().encode(KeynCredentialsResponse(type: .addBulk, browserTab: browserTab))
        let ciphertext = try Crypto.shared.encrypt(message, key: self.sharedKey())
        try self.sendToVolatileQueue(ciphertext: ciphertext).catchLog("Error sending bulk credentials")
        try updateLastRequest()
    }

    /// Respond to a request to log into multiple tabs.
    /// - Parameters:
    ///   - browserTab: This is constant in this case, but not relevant here anyway.
    ///   - accounts: A dictionary of account, where the key is the browser tab.
    ///   - context: Optionally, an authenticated `LAContext` object.
    /// - Throws: Encoding, encryption or network errors.
    mutating func sendBulkLoginResponse(browserTab: Int, accounts: [Int: BulkLoginAccount?], context: LAContext?) throws {
        let message = try JSONEncoder().encode(KeynCredentialsResponse(type: .bulkLogin, browserTab: browserTab, accounts: accounts))
        let ciphertext = try Crypto.shared.encrypt(message, key: self.sharedKey())
        try self.sendToVolatileQueue(ciphertext: ciphertext).catchLog("Error sending bulk credentials")
        try updateLastRequest()
    }

    /// Send the team seed to the client.
    /// - Parameters:
    ///   - id: The team session id.
    ///   - teamId: The team ID.
    ///   - seed: The team seed.
    ///   - browserTab: The browserTab
    ///   - context: Optionally, an authenticated `LAContext` object.
    ///   - organisationKey: The organisation key, used to retrieve organisation PPDs.
    mutating func sendTeamSeed(id: String, teamId: String, seed: String, browserTab: Int, context: LAContext, organisationKey: String?) -> Promise<Void> {
        do {
            let message = try JSONEncoder().encode(KeynCredentialsResponse(type: .createOrganisation,
                                                                           browserTab: browserTab,
                                                                           username: id,
                                                                           password: seed,
                                                                           otp: organisationKey,
                                                                           teamId: teamId))
            let ciphertext = try Crypto.shared.encrypt(message, key: self.sharedKey())
            try self.updateLastRequest()
            return try self.sendToVolatileQueue(ciphertext: ciphertext).asVoid().log("Error sending credentials")
        } catch {
            return Promise(error: error)
        }
    }

    /// Respond to a WebAuthn response.
    /// - Parameters:
    ///   - account: The `UserAccount` that has WebAuthn enabled.
    ///   - browserTab: The browser tab for the client.
    ///   - type: The `ChiffMessageType`, which is either WebAuthn registration or login request.
    ///   - context: Optionally, an authenticated `LAContext` object.
    ///   - signature: The signature, relevant.
    ///   - counter: The counter, if relecant.
    /// - Throws: Encoding, encryption or network errors.
    mutating func sendWebAuthnResponse(account: UserAccount,
                                       browserTab: Int,
                                       type: ChiffMessageType,
                                       context: LAContext,
                                       signature: String?,
                                       counter: Int?) throws {
        var response: KeynCredentialsResponse!
        switch type {
        case .webauthnCreate:
            response = try KeynCredentialsResponse(type: .webauthnCreate,
                                                   browserTab: browserTab,
                                                   signature: signature,
                                                   counter: counter,
                                                   algorithm: account.webAuthn!.algorithm,
                                                   accountId: account.id,
                                                   pubKey: account.webAuthnPubKey())
        case .webauthnLogin:
            response = KeynCredentialsResponse(type: .webauthnLogin, browserTab: browserTab, signature: signature, counter: counter)
        default:
            throw SessionError.unknownType
        }

        let message = try JSONEncoder().encode(response)
        let ciphertext = try Crypto.shared.encrypt(message, key: self.sharedKey())

        try self.sendToVolatileQueue(ciphertext: ciphertext).catchLog("Error sending credentials")
        try updateLastRequest()
    }

    /// Retrieve persistent queue message.
    /// These are used if we must be sured that the message is delivered, for example with password confirmtion messages.
    /// - Parameter shortPolling: Whether we just check once, with a short timeout, or wait for 20 seconds (the maximum) to simulate a push message.
    /// - Returns: An array of `ChiffPersistentQueueMessage`
    func getPersistentQueueMessages(shortPolling: Bool) -> Promise<[ChiffPersistentQueueMessage]> {
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
                var keynMessage: ChiffPersistentQueueMessage = try self.decrypt(message: body)
                keynMessage.receiptHandle = receiptHandle
                return keynMessage
            }
        }
    }

    /// Delete a message from the persistent queue, after it has been received.
    /// - Parameter receiptHandle: The receiptHandle which is used to identity the messaage on the queue.
    func deleteFromPersistentQueue(receiptHandle: String) -> Promise<Void> {
        let message = [
            "receiptHandle": receiptHandle
        ]
        return firstly {
            API.shared.signedRequest(path: "sessions/\(signingPubKey)/browser-to-app", method: .delete, privKey: try signingPrivKey(), message: message)
        }.asVoid().log("Failed to delete password change confirmation from queue.")
    }

    /// Save this session to the Keychain.
    /// - Parameters:
    ///   - key: The encryption key
    ///   - signingKeyPair: The private key
    /// - Throws: Encoding or Keychain errors.
    func save(key: Data, signingKeyPair: KeyPair) throws {
        let sessionData = try PropertyListEncoder().encode(self)
        try Keychain.shared.save(id: SessionIdentifier.sharedKey.identifier(for: id), service: BrowserSession.encryptionService, secretData: key, objectData: sessionData)
        try Keychain.shared.save(id: SessionIdentifier.signingKeyPair.identifier(for: id), service: BrowserSession.signingService, secretData: signingKeyPair.privKey)
    }

    // MARK: - Private functions

    private func decrypt(message message64: String) throws -> ChiffPersistentQueueMessage {
        return try decryptMessage(message: message64)
    }

    private func sendToVolatileQueue(ciphertext: Data) throws -> Promise<[String: Any]> {
        let message = [
            "data": try Crypto.shared.convertToBase64(from: ciphertext)
        ]
        return API.shared.signedRequest(path: "sessions/\(signingPubKey)/volatile", method: .put, privKey: try signingPrivKey(), message: message)
    }

    private func sendByeToPersistentQueue() -> Promise<Void> {
        do {
            let message = try JSONEncoder().encode(ChiffPersistentQueueMessage(passwordSuccessfullyChanged: nil,
                                                                              accountID: nil,
                                                                              type: .end,
                                                                              askToLogin: nil,
                                                                              askToChange: nil,
                                                                              accounts: nil,
                                                                              receiptHandle: nil))
            let ciphertext = try Crypto.shared.encrypt(message, key: sharedKey())
            return API.shared.signedRequest(path: "sessions/\(signingPubKey)/app-to-browser",
                                            method: .put,
                                            privKey: try signingPrivKey(),
                                            message: ["data": ciphertext.base64])
                .asVoid()
                .log("Failed to send bye to persistent queue.")
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
