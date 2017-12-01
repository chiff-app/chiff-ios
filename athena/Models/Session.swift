import Foundation
import Sodium

class Session: Codable {
    let id: String
    var sqsURL: String?
    var appPublicKey: Box.PublicKey?
    
    static let browserService = "com.athena.session.browser"
    static let appService = "com.athena.session.app"

    enum KeyIdentifier: String, Codable {
        case pub = "public"
        case priv = "private"
        case browser = "browser"

        func identifier(for id:String) -> String {
            return "\(id)-\(self.rawValue)"
        }
    }

    init(sqs: String, browserPublicKey: String) {
        // TODO: How can we best determine an identifier? Generate random or deterministic?
        id = (browserPublicKey + sqs).sha256()
    }


    func save(pubKey: String) throws {
        // Save browser public key
        let publicKey = try Crypto.sharedInstance.convertPublicKey(from: pubKey)

        let sessionData = try PropertyListEncoder().encode(self)
        try Keychain.sharedInstance.save(publicKey, id: KeyIdentifier.browser.identifier(for: id), service: Session.browserService, attributes: sessionData)

        // Generate and save own keypair
        let keyPair = try Crypto.sharedInstance.createSessionKeyPair()
        try Keychain.sharedInstance.save(keyPair.publicKey, id: KeyIdentifier.pub.identifier(for: id), service: Session.appService)
        try Keychain.sharedInstance.save(keyPair.secretKey, id: KeyIdentifier.priv.identifier(for: id), service: Session.appService)

        // TODO: should we do this is or implement in function and fetch from Keychain?
        appPublicKey = keyPair.publicKey
    }


    // TODO: Move function to sessionManager?
    func sendPassword(_ message: Data) throws {
        // encrypts message with browser public key for this session.
        let ciphertext = try Crypto.sharedInstance.encrypt(message, pubKey: browserPublicKey(), privKey: appPrivateKey())
        print(ciphertext.base64EncodedString())
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

    private func browserPublicKey() throws -> Box.PublicKey {
        return try Keychain.sharedInstance.get(id: KeyIdentifier.browser.identifier(for: id), service: Session.browserService)
    }

    private func appPrivateKey() throws -> Box.SecretKey {
        return try Keychain.sharedInstance.get(id: KeyIdentifier.priv.identifier(for: id), service: Session.appService)
    }

}
