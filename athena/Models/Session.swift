import Foundation
import Sodium

struct Session: Codable {
    let id: String
    let sqsURL: URL

    enum KeyIdentifier: String, Codable {
        case pub = "public"
        case priv = "private"
        case browser = "browser"

        func identifier(for id:String) -> String {
            return "\(id)-\(self.rawValue)"
        }
    }

    init(sqs: URL, pubKey: String) {
        self.sqsURL = sqs
        
        // TODO: How can we best determine an identifier? Generate random or deterministic?
        id = (pubKey + sqs.absoluteString).sha256()

    }

    func save(pubKey: String) throws {
        // Save browser public key
        let publicKey = try Crypto.convertPublicKey(from: pubKey)
        let sessionData = try PropertyListEncoder().encode(self)
        try Keychain.saveBrowserSessionKey(publicKey, with: KeyIdentifier.browser.identifier(for: id), attributes: sessionData)

        // Generate and save own keypair
        let keyPair = try Crypto.createSessionKeyPair()
        try Keychain.saveAppSessionKey(keyPair.publicKey, with: KeyIdentifier.pub.identifier(for: id))
        try Keychain.saveAppSessionKey(keyPair.secretKey, with: KeyIdentifier.priv.identifier(for: id))

    }

    // Send public key to sqsURL
    func sendSessionInfo(ownPublicKey: Box.PublicKey) throws {
        // TODO: Implement sending to SQS queue

    }

    func sendPassword(_ message: Data) throws {
        // encrypts message with browser public key for this session.
        let ciphertext = try Crypto.encrypt(message, with: id)
        print(ciphertext.base64EncodedString())
    }

    func removeSession() throws {
        do {
            try Keychain.removeBrowserSessionKey(with: KeyIdentifier.browser.identifier(for: id))
            try Keychain.removeAppSessionKey(with: KeyIdentifier.pub.identifier(for: id))
            try Keychain.removeAppSessionKey(with: KeyIdentifier.priv.identifier(for: id))
        } catch {
            throw error
        }
    }

}
