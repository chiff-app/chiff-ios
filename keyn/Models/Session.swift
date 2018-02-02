import Foundation

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
        // TODO: How can we best determine an identifier? Generate random or deterministic?
        id = try "\(browserPublicKey)_\(sqs)".hash()
        sqsQueueName = sqs
        creationDate = Date()
        self.browser = browser
        self.os = os
        try save(pubKey: browserPublicKey)
    }

    private func save(pubKey: String) throws {
        // Save browser public key
        let publicKey = try Crypto.sharedInstance.convertFromBase64(from: pubKey)

        let sessionData = try PropertyListEncoder().encode(self)
        try Keychain.sharedInstance.save(secretData: publicKey, id: KeyIdentifier.browser.identifier(for: id), service: Session.browserService, objectData: sessionData, restricted: false)

        // Generate and save own keypair
        let keyPair = try Crypto.sharedInstance.createSessionKeyPair()
        try Keychain.sharedInstance.save(secretData: keyPair.publicKey, id: KeyIdentifier.pub.identifier(for: id), service: Session.appService, restricted: true)
        try Keychain.sharedInstance.save(secretData: keyPair.secretKey, id: KeyIdentifier.priv.identifier(for: id), service: Session.appService, restricted: false)

    }

    func delete() throws {
        do {
            try Keychain.sharedInstance.delete(id: KeyIdentifier.browser.identifier(for: id), service: Session.browserService)
            try Keychain.sharedInstance.delete(id: KeyIdentifier.pub.identifier(for: id), service: Session.appService)
            try Keychain.sharedInstance.delete(id: KeyIdentifier.priv.identifier(for: id), service: Session.appService)
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
    
    func sendPassword(account: Account) throws {
        let ciphertext = try Crypto.sharedInstance.encrypt(account.password(), pubKey: browserPublicKey(), privKey: appPrivateKey())
        let b64ciphertext = try Crypto.sharedInstance.convertToBase64(from: ciphertext)
       
        // TODO, add request ID etc
        
        // Get SQS queue and send message to queue
        try AWS.sharedInstance.getQueueUrl(queueName: sqsQueueName) { (queueUrl) in
            AWS.sharedInstance.sendToSqs(message: b64ciphertext, to: queueUrl, sessionID: self.id, type: "login")
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
    
}
