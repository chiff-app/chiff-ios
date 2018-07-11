import UIKit
import UserNotifications

enum SessionError: Error {
    case exists
    case invalid
    case noEndpoint
}

class Session: Codable {

    let id: String
    let sqsMessageQueue: String
    let sqsControlQueue: String
    let creationDate: Date
    let browser: String
    let os: String

    private static let browserService = "io.keyn.session.browser"
    private static let appService = "io.keyn.session.app"

    private enum KeyIdentifier: String, Codable {
        case pub = "public"
        case priv = "private"
        case browser = "browser"

        func identifier(for id:String) -> String {
            return "\(id)-\(self.rawValue)"
        }
    }

    init(sqsMessageQueue: String, sqsControlQueue: String, browserPublicKey: String, browser: String, os: String) throws {
        self.sqsMessageQueue = sqsMessageQueue
        self.sqsControlQueue = sqsControlQueue
        self.creationDate = Date()
        self.browser = browser
        self.os = os

        do {
            self.id = try "\(browserPublicKey)_\(sqsMessageQueue)".hash()
            try save(pubKey: browserPublicKey)
        } catch is KeychainError {
            throw SessionError.exists
        } catch is CryptoError {
            throw SessionError.invalid
        }
    }

    func delete(includingQueue: Bool) throws {
        do {
            try Keychain.sharedInstance.delete(id: KeyIdentifier.browser.identifier(for: id), service: Session.browserService)
            try Keychain.sharedInstance.delete(id: KeyIdentifier.pub.identifier(for: id), service: Session.appService)
            try Keychain.sharedInstance.delete(id: KeyIdentifier.priv.identifier(for: id), service: Session.appService)
            if includingQueue { AWS.sharedInstance.sendToSqs(message: "bye", to: sqsControlQueue, sessionID: self.id, type: .end) }
        } catch {
            throw error
        }
    }

    func browserPublicKey() throws -> Data {
        return try Keychain.sharedInstance.get(id: KeyIdentifier.browser.identifier(for: id), service: Session.browserService)
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
    
    // TODO, add request ID etc
    func sendCredentials(account: Account, browserTab: Int, type: BrowserMessageType) throws {
        var response: CredentialsResponse?
        switch type {
        case .addAndChange, .change:
            response = CredentialsResponse(u: account.username, p: try account.password() , np: try account.nextPassword(offset: nil), b: browserTab, a: account.id)
            NotificationCenter.default.post(name: .passwordChangeConfirmation, object: self)
        case .add, .login:
            response = CredentialsResponse(u: account.username, p: try account.password(), np: nil, b: browserTab, a: nil)
        case .register:
            // TODO: create new account, set password etc.
            response = CredentialsResponse(u: account.username, p: try account.password(), np: nil, b: browserTab, a: nil)
        case .confirm:
            response = CredentialsResponse(u: nil, p: nil, np: nil, b: browserTab, a: nil)
        default:
            // TODO: throw error
            return
        }

        let jsonMessage = try JSONEncoder().encode(response!)

        let ciphertext = try Crypto.sharedInstance.encrypt(jsonMessage, pubKey: browserPublicKey(), privKey: appPrivateKey())
        let b64ciphertext = try Crypto.sharedInstance.convertToBase64(from: ciphertext)

        AWS.sharedInstance.sendToSqs(message: b64ciphertext, to: sqsMessageQueue, sessionID: self.id, type: type)
    }
    

    // MARK: Static functions

    static func all() throws -> [Session]? {
        guard let dataArray = try Keychain.sharedInstance.all(service: browserService) else {
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

    static func exists(sqs: String, browserPublicKey: String) throws -> Bool {
        let id = try "\(browserPublicKey)_\(sqs)".hash()
        return Keychain.sharedInstance.has(id: KeyIdentifier.browser.identifier(for: id), service: Session.browserService)
    }

    static func exists(id: String) throws -> Bool {
        return Keychain.sharedInstance.has(id: KeyIdentifier.browser.identifier(for: id), service: Session.browserService)
    }

    static func getSession(id: String) throws -> Session? {
        guard let sessionDict = try Keychain.sharedInstance.attributes(id: KeyIdentifier.browser.identifier(for: id), service: Session.browserService) else {
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
            print(error)
        }

        // To be sure
        Keychain.sharedInstance.deleteAll(service: browserService)
        Keychain.sharedInstance.deleteAll(service: appService)
    }

    static func initiate(sqsMessageQueue: String, sqsControlQueue: String, pubKey: String, browser: String, os: String) throws -> Session {
        // Create session and save to Keychain
        let session = try Session(sqsMessageQueue: sqsMessageQueue, sqsControlQueue: sqsControlQueue, browserPublicKey: pubKey, browser: browser, os: os)
        let pairingResponse = try self.createPairingResponse(session: session)

        AWS.sharedInstance.sendToSqs(message: pairingResponse, to: sqsMessageQueue, sessionID: session.id, type: .pair)

        return session
    }


    // MARK: Private functions

    static private func createPairingResponse(session: Session) throws -> String {
        guard let endpoint = AWS.sharedInstance.snsDeviceEndpointArn else {
            throw SessionError.noEndpoint
        }
        let pairingResponse = try PairingResponse(sessionID: session.id, pubKey: Crypto.sharedInstance.convertToBase64(from: session.appPublicKey()), sns: endpoint)
        let jsonPasswordMessage = try JSONEncoder().encode(pairingResponse)
        let ciphertext = try Crypto.sharedInstance.encrypt(jsonPasswordMessage, pubKey: session.browserPublicKey())
        let b64ciphertext = try Crypto.sharedInstance.convertToBase64(from: ciphertext)

        return b64ciphertext
    }

    private func save(pubKey: String) throws {
        // Save browser public key
        let publicKey = try Crypto.sharedInstance.convertFromBase64(from: pubKey)

        let sessionData = try PropertyListEncoder().encode(self)
        try Keychain.sharedInstance.save(secretData: publicKey, id: KeyIdentifier.browser.identifier(for: id), service: Session.browserService, objectData: sessionData, restricted: false)

        // Generate and save own keypair1
        let keyPair = try Crypto.sharedInstance.createSessionKeyPair()
        try Keychain.sharedInstance.save(secretData: keyPair.publicKey.data, id: KeyIdentifier.pub.identifier(for: id), service: Session.appService, restricted: true)
        try Keychain.sharedInstance.save(secretData: keyPair.secretKey.data, id: KeyIdentifier.priv.identifier(for: id), service: Session.appService, restricted: false)
    }

}
