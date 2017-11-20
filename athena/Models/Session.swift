import Foundation

struct Session {
    let sqsURL: URL
    let nonce: String
    let keyIdentifier: String

    init(sqs: URL, nonce: String, pubKey: String) throws {
        self.sqsURL = sqs
        self.nonce = nonce

        // TODO: How can we best determine an identifier?
        let keyIdentifier = (pubKey + sqs.absoluteString + nonce).sha256()
        self.keyIdentifier = String(keyIdentifier.prefix(8))
        try savePublicKey(from: pubKey, to: self.keyIdentifier)
    }

    func removeSession() {
        do {
            try Keychain.removeSessionKey(with: keyIdentifier)
        } catch {
            print(error)
        }
    }

    func savePublicKey(from base64EncodedKey: String, to keyIdentifier: String) throws {
        // Convert from base64 to SecKey
        let publicKey = try Crypto.convertPublicKey(from: base64EncodedKey)

        // Store key
        try Keychain.saveSessionKey(publicKey, with: keyIdentifier)
    }
}
