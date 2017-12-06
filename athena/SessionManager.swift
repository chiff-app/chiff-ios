//
//  SessionManager.swift
//  athena
//
//  Created by bas on 01/12/2017.
//  Copyright © 2017 athena. All rights reserved.
//

import Foundation

enum SessionError: Error {
    case accountNotFound
    case JSONEncoding
}

class SessionManager {

    static let sharedInstance = SessionManager()

    private init() { }

    func initiateSession(sqs: String, pubKey: String, siteID: String) throws {
        // Create session and save to Keychain
        let session = Session(sqs: sqs, browserPublicKey: pubKey)
        try session.save(pubKey: pubKey)

        // Get Account object for site x
        // TODO: What if there are multiple accounts with same siteID (different usernames). Present choice to user?
        guard let account = try Account.get(siteID: siteID) else {
            throw SessionError.accountNotFound
        }
        

        let passwordMessage = try self.createPasswordMessage(session: session, account: account, siteID: siteID)

        // Get SQS queue and send message to queue
        try AWS.sharedInstance.getQueueUrl(queueName: sqs) { (queueUrl) in
            // This isn't right. QueueURL is set after session object is already saved, so it's pointless. If session is added to array here, devicesTableViewController will display incorrectly and if it's added synchronously and saved here there might be discrepancies between storage (Keychain) and memory (sessions array). How to solve this?
            // Possible solution: display loading bar when scanning QR. This provides opportunity to verify the correct message has been received by the browser by displaying a (second) QR code with hash. So user has to hold phone until second QR is displayed, only then key exchange is authenticated.
            session.sqsURL = queueUrl
            AWS.sharedInstance.sendToSqs(message: passwordMessage, to: queueUrl)
        }
    }

    
    private func createPasswordMessage(session: Session, account: Account, siteID: String) throws -> String {
        let credentials = try Credentials(siteID: siteID, username: account.username, password: account.password())
        let base64PublicKey = try Crypto.sharedInstance.convertToBase64(from: session.appPublicKey())

        let passwordMessage = PasswordMessage(pubKey: base64PublicKey, sns: AWS.sharedInstance.snsARN, creds: credentials)

        let jsonPasswordMessage = try JSONEncoder().encode(passwordMessage)
        
        let ciphertext = try Crypto.sharedInstance.encrypt(jsonPasswordMessage, pubKey: session.browserPublicKey(), privKey: session.appPrivateKey())

        let b64ciphertext = try Crypto.sharedInstance.convertToBase64(from: ciphertext)
        
        return b64ciphertext
    }

    
}
