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
    var sessions: [Session]

    private init() {
        // TODO: is try! okay to use here?
        if let storedSessions = try! Session.all() {
            sessions = storedSessions
            print("Loading sessions from keychain.")
        } else {
            sessions = [Session]()
            print("No stored sessions found.")
        }
    }

    func initiateSession(sqs: String, pubKey: String, siteID: String) throws {
        // Create session and save to Keychain
        let session = Session(sqs: sqs, browserPublicKey: pubKey)
        try session.save(pubKey: pubKey)
        sessions.append(session)

        // Get Account object for site x
        // TODO: What if there are multiple accounts with same siteID (different usernames). Present choice to user?
        guard let account = try Account.get(siteID: siteID) else {
            throw SessionError.accountNotFound
        }

        let passwordMessage = try self.createPasswordMessage(session: session, account: account)

        // Get SQS queue and send message to queue
        try AWS.sharedInstance.getQueueUrl(queueName: sqs) { (queueUrl) in
            // This isn't right. QueueURL is set after session object is already saved, so it's pointsless. If session is added to array here, devicesTableViewController will display incorrectly and if it's added synchronously and saved here there might be discrepancies between storage (Keychain) and memory (sessions array). How to solve this?
            session.sqsURL = queueUrl
            AWS.sharedInstance.sendToSqs(message: passwordMessage, to: queueUrl)
        }
    }

    // TODO: Encrypt message (see function in Session)
    private func createPasswordMessage(session: Session, account: Account) throws -> String {
        let credentials = try Credentials(username: account.username, password: account.password())
        let base64PublicKey = try Crypto.sharedInstance.convertPublicKey(from: session.appPublicKey!)

        let passwordMessage = PasswordMessage(pubKey: base64PublicKey, sns: AWS.sharedInstance.snsARN, creds: credentials)

        let jsonPasswordMessageData = try JSONEncoder().encode(passwordMessage)
        guard let jsonPasswordMessage = String(data: jsonPasswordMessageData, encoding: .utf8) else {
            throw SessionError.JSONEncoding
        }

        return jsonPasswordMessage
    }

    
}
