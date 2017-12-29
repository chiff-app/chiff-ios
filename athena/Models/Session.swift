import Foundation

class Session: Codable {
    let id: String
    let sqsQueueName: String
    let creationDate: Date
    let browser: String
    let os: String

    private static let browserService = "com.athena.session.browser"
    private static let appService = "com.athena.session.app"

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
        try Keychain.sharedInstance.save(publicKey, id: KeyIdentifier.browser.identifier(for: id), service: Session.browserService, attributes: sessionData)

        // Generate and save own keypair
        let keyPair = try Crypto.sharedInstance.createSessionKeyPair()
        try Keychain.sharedInstance.save(keyPair.publicKey, id: KeyIdentifier.pub.identifier(for: id), service: Session.appService)
        try Keychain.sharedInstance.save(keyPair.secretKey, id: KeyIdentifier.priv.identifier(for: id), service: Session.appService)

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
    
}
