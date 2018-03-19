import Foundation

enum SessionError: Error {
    case exists
    case invalid
}

class Session: Codable {

    let id: String
    let sqsQueueName: String
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

    init(sqs: String, browserPublicKey: String, browser: String, os: String) throws {
        self.sqsQueueName = sqs
        self.creationDate = Date()
        self.browser = browser
        self.os = os

        do {
            self.id = try "\(browserPublicKey)_\(sqs)".hash()
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
            if includingQueue {
                try AWS.sharedInstance.getQueueUrl(queueName: sqsQueueName) { (queueUrl) in
                    AWS.sharedInstance.sendToSqs(message: "bye", to: queueUrl, sessionID: self.id, type: .end)
                }
            }
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
        let data = try Crypto.sharedInstance.decrypt(ciphertext, privKey: appPrivateKey(), pubKey: browserPublicKey())
        return String(data: data, encoding: .utf8)!
    }

    func decrypt(message: String) throws -> BrowserMessage {
        let ciphertext = try Crypto.sharedInstance.convertFromBase64(from: message)
        let data = try Crypto.sharedInstance.decrypt(ciphertext, privKey: appPrivateKey(), pubKey: browserPublicKey())
        return try JSONDecoder().decode(BrowserMessage.self, from: data)
    }
    
    // TODO, add request ID etc
    func sendCredentials(account: Account, browserTab: Int, type: BrowserMessageType) throws {
        var response: CredentialsResponse?
        var account = account
        switch type {
        case .login:
            response = CredentialsResponse(u: account.username, p: try account.password(), np: nil, b: browserTab)
        case .register:
            // TODO: create new account, set password etc.
            response = CredentialsResponse(u: account.username, p: try account.password(), np: nil, b: browserTab)
        case .reset:
            // TODO: change password. We should probably implement some kind of feedback mechanism from browser if reset was succesful, otherwise password will be deleted. Also, how to handle offsets? Request should allow user to type custom password somehow
            let oldPassword: String = try account.password()
            try account.updatePassword(restrictions: nil, offset: nil)
            response = CredentialsResponse(u: account.username, p: oldPassword , np: try account.password(), b: browserTab)
        default:
            // TODO: throw error
            return
        }

        let jsonMessage = try JSONEncoder().encode(response!)

        let ciphertext = try Crypto.sharedInstance.encrypt(jsonMessage, pubKey: browserPublicKey(), privKey: appPrivateKey())
        let b64ciphertext = try Crypto.sharedInstance.convertToBase64(from: ciphertext)

        // Get SQS queue and send message to queue
        try AWS.sharedInstance.getQueueUrl(queueName: sqsQueueName) { (queueUrl) in
            AWS.sharedInstance.sendToSqs(message: b64ciphertext, to: queueUrl, sessionID: self.id, type: type)
        }
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
        Keychain.sharedInstance.deleteAll(service: browserService)
        Keychain.sharedInstance.deleteAll(service: appService)
    }

    // MARK: Private functions

    private func save(pubKey: String) throws {
        // Save browser public key
        let publicKey = try Crypto.sharedInstance.convertFromBase64(from: pubKey)

        let sessionData = try PropertyListEncoder().encode(self)
        try Keychain.sharedInstance.save(secretData: publicKey, id: KeyIdentifier.browser.identifier(for: id), service: Session.browserService, objectData: sessionData, restricted: false)

        // Generate and save own keypair1
        let keyPair = try Crypto.sharedInstance.createSessionKeyPair()
        try Keychain.sharedInstance.save(secretData: keyPair.publicKey, id: KeyIdentifier.pub.identifier(for: id), service: Session.appService, restricted: true)
        try Keychain.sharedInstance.save(secretData: keyPair.secretKey, id: KeyIdentifier.priv.identifier(for: id), service: Session.appService, restricted: false)
    }

}
