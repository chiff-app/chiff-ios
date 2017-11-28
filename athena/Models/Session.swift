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
        let publicKey = try Crypto.sharedInstance.convertPublicKey(from: pubKey)
        let sessionData = try PropertyListEncoder().encode(self)
        try Keychain.sessions.saveBrowserKey(publicKey, with: KeyIdentifier.browser.identifier(for: id), attributes: sessionData)

        // Generate and save own keypair
        let keyPair = try Crypto.sharedInstance.createSessionKeyPair()
        try Keychain.sessions.saveAppKey(keyPair.publicKey, with: KeyIdentifier.pub.identifier(for: id))
        try Keychain.sessions.saveAppKey(keyPair.secretKey, with: KeyIdentifier.priv.identifier(for: id))

    }

    // Send public key to sqsURL
    func sendSessionInfo() throws {
        // TODO: Implement sending to SQS queue. Make struct and convert to JSON?
        //let appPublicKey = try Keychain.sessions.getAppKey(with: KeyIdentifier.pub.identifier(for: id))
        //let snsURL = "TODO"

    }

    func sendPassword(_ message: Data) throws {
        // encrypts message with browser public key for this session.
        let ciphertext = try Crypto.sharedInstance.encrypt(message, with: id)
        print(ciphertext.base64EncodedString())
    }

    func removeSession() throws {
        do {
            try Keychain.sessions.deleteBrowserKey(with: KeyIdentifier.browser.identifier(for: id))
            try Keychain.sessions.deleteAppKey(with: KeyIdentifier.pub.identifier(for: id))
            try Keychain.sessions.deleteAppKey(with: KeyIdentifier.priv.identifier(for: id))
        } catch {
            throw error
        }
    }

}
