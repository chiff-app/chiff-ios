//
//  QueueHandler.swift
//  keyn
//
//  Created by Bas Doorn on 18/09/2020.
//  Copyright © 2020 keyn. All rights reserved.
//

import Foundation
import LocalAuthentication
import PromiseKit

class QueueHandler {

    static let shared = QueueHandler()

    private let pollingAttempts = 5

    private var listening = false

    func start() {
        guard !listening else {
            return
        }
        NotificationCenter.default.addObserver(self, selector: #selector(checkPersistentQueueListener(notification:)), name: .accountsLoaded, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(waitForPasswordChangeConfirmation(notification:)), name: .passwordChangeConfirmation, object: nil)
        listening = true
    }

    @objc func checkPersistentQueueListener(notification: Notification?) {
        _ = self.checkPersistentQueue(notification: notification)
    }

    func checkPersistentQueue(notification: Notification?) -> Promise<Void> {
        return firstly {
            when(fulfilled: try BrowserSession.all().map { session in
                self.pollQueue(attempts: 1, session: session, shortPolling: true).asVoid()
            })
        }.log("Error checking persistent queue for messages")
    }

    @objc private func waitForPasswordChangeConfirmation(notification: Notification) {
        guard let session = notification.object as? BrowserSession else {
            Logger.shared.warning("Received notification from unexpected object")
            return
        }

        firstly {
            pollQueue(attempts: pollingAttempts, session: session, shortPolling: false)
        }.catchLog("Error getting password change confirmation from persistent queue.")
    }

    private func pollQueue(attempts: Int, session: BrowserSession, shortPolling: Bool) -> Promise<[BulkAccount]?> {
        return firstly {
            session.getPersistentQueueMessages(shortPolling: shortPolling)
        }.then { (messages: [KeynPersistentQueueMessage]) -> Promise<[BulkAccount]?> in
            if messages.isEmpty {
                return attempts > 1 ? self.pollQueue(attempts: attempts - 1, session: session, shortPolling: shortPolling) : .value(nil)
            } else {
                var promises: [Promise<[BulkAccount]?>] = []
                for message in messages {
                    promises.append(try self.handlePersistentQueueMessage(keynMessage: message, session: session))
                }
                return when(fulfilled: promises).map { (result: [[BulkAccount]?]) -> [BulkAccount]? in
                    if result.isEmpty {
                        return nil
                    } else {
                        return result.first(where: { $0 != nil }) ?? nil
                    }
                }
            }
        }

    }

    private func handlePersistentQueueMessage(keynMessage: KeynPersistentQueueMessage, session: BrowserSession) throws -> Promise<[BulkAccount]?> {
        guard let receiptHandle = keynMessage.receiptHandle else {
            throw CodingError.missingData
        }
        var result: [BulkAccount]?
        switch keynMessage.type {
        case .confirm:
            guard let accountId = keynMessage.accountID, let result = keynMessage.passwordSuccessfullyChanged else {
                throw CodingError.missingData
            }
            guard var account = try UserAccount.get(id: accountId, context: nil) else {
                throw AccountError.notFound
            }
            if result {
                try account.updatePasswordAfterConfirmation(context: nil)
            }
        case .preferences:
            guard let accountId = keynMessage.accountID else {
                throw CodingError.missingData
            }
            guard var account = try UserAccount.get(id: accountId, context: nil) else {
                throw AccountError.notFound
            }
            try account.update(username: nil, password: nil, siteName: nil, url: nil, askToLogin: keynMessage.askToLogin, askToChange: keynMessage.askToChange)
        case .addBulk:
            result = keynMessage.accounts!
        default:
            Logger.shared.warning("Unknown message type received", userInfo: ["messageType": keynMessage.type.rawValue ])
        }
        return session.deleteFromPersistentQueue(receiptHandle: receiptHandle).map { _ in
            result
        }
    }

}
