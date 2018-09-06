import UIKit
import UserNotifications
import JustLog

enum SessionError: Error {
    case exists
    case invalid
    case noEndpoint
}

class Session: Codable {

    let id: String
    let messagePubKey: String
    let controlPubKey: String
    let encryptionPubKey: String
    let creationDate: Date
    let browser: String
    let os: String
    var backgroundTask: UIBackgroundTaskIdentifier = UIBackgroundTaskInvalid

    private static let messageQueueService = "io.keyn.session.message"
    private static let controlQueueService = "io.keyn.session.control"
    private static let appService = "io.keyn.session.app"

    private enum KeyIdentifier: String, Codable {
        case pub = "public"
        case priv = "private"
        case control = "control"
        case message = "message"
        
        func identifier(for id:String) -> String {
            return "\(id)-\(self.rawValue)"
        }
    }

    init(encryptionPubKey: String, messagePubKey: String, controlPubKey: String, browser: String, os: String) {
        self.encryptionPubKey = encryptionPubKey
        self.messagePubKey = messagePubKey
        self.controlPubKey = controlPubKey
        self.creationDate = Date()
        self.browser = browser
        self.os = os
        self.id = "\(encryptionPubKey)_\(messagePubKey)".hash()
    }

    func delete(includingQueue: Bool) throws {
        Logger.shared.info("Session ended.", userInfo: ["code": AnalyticsMessage.sessionEnd.rawValue, "appInitiated": includingQueue])
        if includingQueue { try sendToControlQueue(message: "Ynll") }
        try Keychain.sharedInstance.delete(id: KeyIdentifier.control.identifier(for: id), service: Session.controlQueueService)
        try Keychain.sharedInstance.delete(id: KeyIdentifier.message.identifier(for: id), service: Session.messageQueueService)
        try Keychain.sharedInstance.delete(id: KeyIdentifier.pub.identifier(for: id), service: Session.appService)
        try Keychain.sharedInstance.delete(id: KeyIdentifier.priv.identifier(for: id), service: Session.appService)
    }
    
    func browserPublicKey() throws -> Data {
        return try Crypto.sharedInstance.convertFromBase64(from: encryptionPubKey)
    }

    func appPrivateKey() throws -> Data {
        return try Keychain.sharedInstance.get(id: KeyIdentifier.priv.identifier(for: id), service: Session.appService)
    }
    
    func appPublicKey() throws -> Data {
        return try Keychain.sharedInstance.get(id: KeyIdentifier.pub.identifier(for: id), service: Session.appService)
    }

    func decrypt(message: String) throws -> String {
        let ciphertext = try Crypto.sharedInstance.convertFromBase64(from: message)
        let (data, _) = try Crypto.sharedInstance.decrypt(ciphertext, privKey: appPrivateKey(), pubKey: browserPublicKey())
        return String(data: data, encoding: .utf8)!
    }

    func decrypt(message: String) throws -> BrowserMessage {
        let ciphertext = try Crypto.sharedInstance.convertFromBase64(from: message)
        let (data, _) = try Crypto.sharedInstance.decrypt(ciphertext, privKey: appPrivateKey(), pubKey: browserPublicKey())
        let browserMessage = try JSONDecoder().decode(BrowserMessage.self, from: data)
        return browserMessage
    }
    
    func acknowledge(browserTab: Int) throws {
        let response = CredentialsResponse(u: nil, p: nil, np: nil, b: browserTab, a: nil)
        let jsonMessage = try JSONEncoder().encode(response)
        let ciphertext = try Crypto.sharedInstance.encrypt(jsonMessage, pubKey: browserPublicKey(), privKey: appPrivateKey())
        try sendToMessageQueue(ciphertext: ciphertext, type: BrowserMessageType.acknowledge)
    }
    
    // TODO, add request ID etc
    func sendCredentials(account: Account, browserTab: Int, type: BrowserMessageType) throws {
        var response: CredentialsResponse?
        var account = account
        switch type {
        case .addAndChange:
            response = CredentialsResponse(u: account.username, p: try account.password() , np: try account.nextPassword(offset: nil), b: browserTab, a: account.id)
            NotificationCenter.default.post(name: .passwordChangeConfirmation, object: self)
        case .change:
            response = CredentialsResponse(u: account.username, p: try account.password() , np: try account.nextPassword(offset: nil), b: browserTab, a: account.id)
            NotificationCenter.default.post(name: .passwordChangeConfirmation, object: self)
        case .add:
            response = CredentialsResponse(u: account.username, p: try account.password(), np: nil, b: browserTab, a: nil)
        case .login:
            Logger.shared.info("Login response sent.", userInfo: ["code": AnalyticsMessage.loginResponse.rawValue, "siteName": account.site.name])
            response = CredentialsResponse(u: account.username, p: try account.password(), np: nil, b: browserTab, a: nil)
        case .fill:
            Logger.shared.info("Fill password response sent.", userInfo: ["code": AnalyticsMessage.fillResponse.rawValue, "siteName": account.site.name])
            response = CredentialsResponse(u: nil, p: try account.password(), np: nil, b: browserTab, a: nil)
        case .register:
            Logger.shared.info("Register response sent.", userInfo: ["code": AnalyticsMessage.registrationResponse.rawValue,     "siteName": account.site.name])
            // TODO: create new account, set password etc.
            response = CredentialsResponse(u: account.username, p: try account.password(), np: nil, b: browserTab, a: nil)
        case .acknowledge:
            response = CredentialsResponse(u: nil, p: nil, np: nil, b: browserTab, a: nil)
        default:
            // TODO: throw error
            return
        }

        let message = try JSONEncoder().encode(response!)
        let ciphertext = try Crypto.sharedInstance.encrypt(message, pubKey: Crypto.sharedInstance.convertFromBase64(from: encryptionPubKey), privKey: appPrivateKey())
        try sendToMessageQueue(ciphertext: ciphertext, type: type)
    }
    
    func sendToMessageQueue(ciphertext: Data, type: BrowserMessageType) throws {
        let message = try Crypto.sharedInstance.convertToBase64(from: ciphertext)
        let parameters = try sign(data: message, requestType: .post, privKey: Keychain.sharedInstance.get(id: KeyIdentifier.message.identifier(for: id), service: Session.messageQueueService), type: type)
        try API.sharedInstance.post(type: .message, path: messagePubKey, parameters: parameters, body: nil)
    }
    
    func sendToControlQueue(message: String) throws {
        let parameters = try sign(data: message, requestType: .post, privKey: Keychain.sharedInstance.get(id: KeyIdentifier.control.identifier(for: id), service: Session.controlQueueService), type: .end)
        try API.sharedInstance.post(type: .message, path: controlPubKey, parameters: parameters, body: nil)
    }
    
    func getChangeConfirmations(shortPolling: Bool, completionHandler: @escaping (_ result: [String: Any]) -> Void) throws {
        let parameters = try sign(data: nil, requestType: .get, privKey: Keychain.sharedInstance.get(id: KeyIdentifier.control.identifier(for: id), service: Session.controlQueueService), type: nil, waitTime: shortPolling ? "0" : "20")
        API.sharedInstance.get(type: .message, path: controlPubKey, parameters: parameters, completionHandler: completionHandler)
    }
    
    func deleteChangeConfirmation(receiptHandle: String) {
        do {
            let parameters = try sign(data: nil, requestType: .delete, privKey: Keychain.sharedInstance.get(id: KeyIdentifier.control.identifier(for: id), service: Session.controlQueueService), type: nil, receiptHandle: receiptHandle)
            try API.sharedInstance.delete(type: .message, path: controlPubKey, parameters: parameters, body: nil)
        } catch {
            Logger.shared.warning("Failed to delete change confirmation from queue.")
        }
    }
    

    // MARK: Static functions

    static func all() throws -> [Session]? {
        guard let dataArray = try Keychain.sharedInstance.all(service: messageQueueService) else {
            return nil
        }

        var sessions = [Session]()
        let decoder = PropertyListDecoder()

        for dict in dataArray {
            guard let sessionData = dict[kSecAttrGeneric as String] as? Data else {
                throw KeychainError.unexpectedData
            }
            sessions.append(try decoder.decode(Session.self, from: sessionData))
        }
        return sessions
    }

    static func exists(encryptionPubKey: String, queueSeed: String) throws -> Bool {
        let seed = try Crypto.sharedInstance.deriveKey(key: queueSeed, context: "message", index: 1)
        let messageKeyPair = try Crypto.sharedInstance.createSigningKeyPair(seed: seed)
        let messagePubKey = try Crypto.sharedInstance.convertToBase64(from: messageKeyPair.publicKey.data)
        let id = "\(encryptionPubKey)_\(messagePubKey)".hash()
        return Keychain.sharedInstance.has(id: KeyIdentifier.message.identifier(for: id), service: Session.messageQueueService)
    }

    static func exists(id: String) throws -> Bool {
        return Keychain.sharedInstance.has(id: KeyIdentifier.message.identifier(for: id), service: Session.messageQueueService)
    }

    static func getSession(id: String) throws -> Session? {
        guard let sessionDict = try Keychain.sharedInstance.attributes(id: KeyIdentifier.message.identifier(for: id), service: Session.messageQueueService) else {
            return nil
        }
        guard let sessionData = sessionDict[kSecAttrGeneric as String] as? Data else {
            throw KeychainError.unexpectedData
        }
        let decoder = PropertyListDecoder()
        return try decoder.decode(Session.self, from: sessionData)
    }

    static func deleteAll() {
        do {
            if let sessions = try Session.all() {
                for session in sessions {
                    try session.delete(includingQueue: true)
                }
            }
        } catch {
            Logger.shared.debug("Error deleting accounts.", error: error as NSError)
        }

        // To be sure
        Keychain.sharedInstance.deleteAll(service: messageQueueService)
        Keychain.sharedInstance.deleteAll(service: controlQueueService)
        Keychain.sharedInstance.deleteAll(service: appService)
    }

    static func initiate(queueSeed: String, pubKey: String, browser: String, os: String) throws -> Session {
        // Create session and save to Keychain
        let messageKeyPair = try Crypto.sharedInstance.createSigningKeyPair(seed: Crypto.sharedInstance.deriveKey(key: queueSeed, context: "message", index: 1))
        let controlKeyPair = try Crypto.sharedInstance.createSigningKeyPair(seed: Crypto.sharedInstance.deriveKey(key: queueSeed, context: "control", index: 2))
        let messagePubKey = try Crypto.sharedInstance.convertToBase64(from: messageKeyPair.publicKey.data)
        let controlPubKey = try Crypto.sharedInstance.convertToBase64(from: controlKeyPair.publicKey.data)
        let session = Session(encryptionPubKey: pubKey, messagePubKey: messagePubKey, controlPubKey: controlPubKey, browser: browser, os: os)
        
        do {
            try session.save(messagePrivKey: messageKeyPair.secretKey.data, controlPrivKey: controlKeyPair.secretKey.data)
        } catch is KeychainError {
            throw SessionError.exists
        } catch is CryptoError {
            throw SessionError.invalid
        }
        
        let pairingResponse = try self.createPairingResponse(session: session)
        try session.sendToMessageQueue(ciphertext: pairingResponse, type: BrowserMessageType.pair)

        return session
    }


    // MARK: Private functions

    static private func createPairingResponse(session: Session) throws -> Data {
        guard let endpoint = AWS.sharedInstance.snsDeviceEndpointArn else {
            throw SessionError.noEndpoint
        }
        let pairingResponse = try PairingResponse(sessionID: session.id, pubKey: Crypto.sharedInstance.convertToBase64(from: session.appPublicKey()), sns: endpoint, userID: Properties.userID())
        let jsonPasswordMessage = try JSONEncoder().encode(pairingResponse)
        return try Crypto.sharedInstance.encrypt(jsonPasswordMessage, pubKey: session.browserPublicKey())
    }

    private func save(messagePrivKey: Data, controlPrivKey: Data) throws {
        // Save browser public key

        let sessionData = try PropertyListEncoder().encode(self) // Now contains public keys
        try Keychain.sharedInstance.save(secretData: messagePrivKey, id: KeyIdentifier.message.identifier(for: id), service: Session.messageQueueService, objectData: sessionData, restricted: false)
        try Keychain.sharedInstance.save(secretData: controlPrivKey, id: KeyIdentifier.control.identifier(for: id), service: Session.controlQueueService, restricted: false)

        // Generate and save own keypair1
        let keyPair = try Crypto.sharedInstance.createSessionKeyPair()
        try Keychain.sharedInstance.save(secretData: keyPair.publicKey.data, id: KeyIdentifier.pub.identifier(for: id), service: Session.appService, restricted: true)
        try Keychain.sharedInstance.save(secretData: keyPair.secretKey.data, id: KeyIdentifier.priv.identifier(for: id), service: Session.appService, restricted: false)
    }
    
    private func sign(data: String?, requestType: APIRequestType, privKey: Data, type: BrowserMessageType?, waitTime: String? = nil, receiptHandle: String? = nil) throws -> [String:String] {
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
        
        let data = try JSONSerialization.data(withJSONObject: message, options: [])
        let signature = try Crypto.sharedInstance.sign(message: data, privKey: privKey)

        var parameters = [
            "m": try Crypto.sharedInstance.convertToBase64(from: data),
            "s": try Crypto.sharedInstance.convertToBase64(from: signature)
        ]
        if let type = type {
            parameters["t"] = String(type.rawValue)
        }
        return parameters
    }

}
