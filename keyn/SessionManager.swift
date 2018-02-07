import Foundation

class SessionManager {

    static let sharedInstance = SessionManager()

    private init() { }

    func initiateSession(sqs: String, pubKey: String, browser: String, os: String) throws -> Session {
        // Create session and save to Keychain
        let session = try Session(sqs: sqs, browserPublicKey: pubKey, browser: browser, os: os)
        let pairingResponse = try self.createPairingResponse(session: session)

        // Get SQS queue and send message to queue
        try AWS.sharedInstance.getQueueUrl(queueName: sqs) { (queueUrl) in
            AWS.sharedInstance.sendToSqs(message: pairingResponse, to: queueUrl, sessionID: session.id, type: "pair")
        }

        return session
    }

    private func createPairingResponse(session: Session) throws -> String {
        guard let endpoint = AWS.sharedInstance.snsDeviceEndpointArn else {
            return "" // TODO Throw error
        }
        let pairingResponse = try PairingResponse(sessionID: session.id, pubKey: Crypto.sharedInstance.convertToBase64(from: session.appPublicKey()), sns: endpoint)
        let jsonPasswordMessage = try JSONEncoder().encode(pairingResponse)
        let ciphertext = try Crypto.sharedInstance.encrypt(jsonPasswordMessage, pubKey: session.browserPublicKey())
        let b64ciphertext = try Crypto.sharedInstance.convertToBase64(from: ciphertext)

        return b64ciphertext
    }
    
}
