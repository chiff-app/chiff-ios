//
//  TeamSession+Restorable.swift
//  keyn
//
//  Created by Bas Doorn on 17/03/2020.
//  Copyright © 2020 keyn. All rights reserved.
//

import Foundation
import LocalAuthentication
import PromiseKit

extension TeamSession: Restorable {
    
    static var backupEndpoint: BackupEndpoint {
        return .sessions
    }

    static func restore(data: Data, context: LAContext?) throws -> TeamSession {
        return try TeamSession(data: data, context: context)
    }

    static func backupSync(context: LAContext) throws -> Promise<Void> {
        guard let key = try Keychain.shared.get(id: KeyIdentifier.encryption.identifier(for: .backup), service: .backup) else {
            throw KeychainError.notFound
        }
        return firstly {
            API.shared.signedRequest(method: .get, message: nil, path: "users/\(try BackupManager.publicKey())/\(backupEndpoint.rawValue)", privKey: try BackupManager.privateKey(), body: nil)
        }.map { result in
            var changed = false
            var currentSessions = try Self.all()
            for (id, data) in result {
                if let base64Data = data as? String {
                    do {
                        let ciphertext = try Crypto.shared.convertFromBase64(from: base64Data)
                        let data = try Crypto.shared.decryptSymmetric(ciphertext, secretKey: key)
                        if var session = try get(id: id, context: context) {
                            currentSessions.removeAll(where: { $0.id == session.id })
                            let backupSession = try JSONDecoder().decode(BackupTeamSession.self, from: data)
                            if backupSession.title != session.title {
                                session.title = backupSession.title
                                changed = true
                            }
                        } else {
                            let _ = try restore(data: data, context: context)
                            changed = true
                        }
                    } catch {
                        Logger.shared.error("Could not restore team session.", error: error)
                    }
                }
            }
            for session in currentSessions {
                #warning("Check how to safely delete here in the background")
                try session.delete(backup: false)
                changed = true
            }
            if changed {
                NotificationCenter.default.postMain(name: .sessionUpdated, object: self)
            }
        }.asVoid().recover { error in
            if case KeychainError.interactionNotAllowed = error {
                // Probably happend in the background, we'll sync when authenticated again
                return
            } else {
                throw error
            }
        }.log("Error syncing accounts")
    }

    init(data: Data, context: LAContext?) throws {
        let backupSession = try JSONDecoder().decode(BackupTeamSession.self, from: data)
        let (passwordSeed, encryptionKey, signingKeyPair) = try TeamSession.createTeamSessionKeys(seed: backupSession.seed)
        creationDate = Date()
        id = backupSession.id
        signingPubKey = signingKeyPair.pubKey.base64
        title = backupSession.title
        version = backupSession.version
        isAdmin = false
        created = true
        try save(key: encryptionKey, signingKeyPair: signingKeyPair, passwordSeed: passwordSeed)
    }

    func backup() -> Promise<Void> {
        do {
            guard let seed = try Keychain.shared.get(id: SessionIdentifier.sharedSeed.identifier(for: self.id), service: .signingTeamSessionKey), created else {
                // Backup complete
                return .value(())
            }
            let backupSession = BackupTeamSession(id: id, seed: seed, title: title , version: version)
            let data = try JSONEncoder().encode(backupSession)
            return firstly {
                backup(data: data)
            }.map { _ in
                // Occurs if backup failed earlier, but succeeded now: delete sharedSeed from Keychain
                try Keychain.shared.delete(id: SessionIdentifier.sharedSeed.identifier(for: self.id), service: .signingTeamSessionKey)
            }.recover { error in
                // Occurs if backup failed now, so we can try next time
                try Keychain.shared.save(id: SessionIdentifier.sharedSeed.identifier(for: self.id), service: .signingTeamSessionKey, secretData: seed)
                throw error
            }.log("Error updating team session backup state")
        } catch {
            Logger.shared.error("Error updating team session backup state", error: error)
            return Promise(error: error)
        }

    }

}

fileprivate struct BackupTeamSession: Codable {
    let id: String
    let seed: Data
    let title: String
    let version: Int
}
