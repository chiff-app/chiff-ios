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

    func initiateSession(sqs: String, pubKey: String, browser: String, os: String) throws {
        // Create session and save to Keychain
        let session = try Session(sqs: sqs, browserPublicKey: pubKey, browser: browser, os: os)
//
//        // Get Account object for site x
//        // TODO: What if there are multiple accounts with same siteID (different usernames). Present choice to user?
//        guard let account = try Account.get(siteID: siteID) else {
//            throw SessionError.accountNotFound
//        }

        let pairingResponse = try self.createPairingResponse(session: session)

        // Get SQS queue and send message to queue
        try AWS.sharedInstance.getQueueUrl(queueName: sqs) { (queueUrl) in
            AWS.sharedInstance.sendToSqs(message: pairingResponse, to: queueUrl, sessionID: session.id)
        }
    }

    
    private func createPairingResponse(session: Session) throws -> String {
        let pairingResponse = try PairingResponse(sessionID: session.id, pubKey: Crypto.sharedInstance.convertToBase64(from: session.appPublicKey()), sns: AWS.sharedInstance.snsARN)
        let jsonPasswordMessage = try JSONEncoder().encode(pairingResponse)
        let ciphertext = try Crypto.sharedInstance.encrypt(jsonPasswordMessage, pubKey: session.browserPublicKey())
        let b64ciphertext = try Crypto.sharedInstance.convertToBase64(from: ciphertext)

        return b64ciphertext
    }

    
}
