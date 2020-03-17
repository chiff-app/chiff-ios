//
//  TeamSession+Restorable.swift
//  keyn
//
//  Created by Bas Doorn on 17/03/2020.
//  Copyright © 2020 keyn. All rights reserved.
//

import Foundation
import LocalAuthentication

extension TeamSession: Restorable {

    static var backupEndpoint: BackupEndpoint {
        return .sessions
    }

    static func restore(data: Data, id: String, context: LAContext?) throws -> TeamSession {
        let decoder = JSONDecoder()
        let backupSession = try decoder.decode(BackupTeamSession.self, from: data)
        let (passwordSeed, encryptionKey, signingKeyPair) = try createTeamSessionKeys(seed: backupSession.seed)
        let session = TeamSession(id: backupSession.id, signingPubKey: signingKeyPair.pubKey, title: backupSession.title, version: backupSession.version, isAdmin: false, created: true)
        try session.save(key: encryptionKey, signingKeyPair: signingKeyPair, passwordSeed: passwordSeed)
        return session
    }

    func backup(seed generatedSeed: Data?, group: DispatchGroup? = nil) {
        do {
            let keychainSeed: Data? = generatedSeed == nil ? try Keychain.shared.get(id: SessionIdentifier.sharedSeed.identifier(for: self.id), service: .signingTeamSessionKey) : nil
            guard let seed = generatedSeed ?? keychainSeed else {
                // Backup complete
                group?.leave()
                return
            }
            let backupSession = BackupTeamSession(id: id, seed: seed, title: title , version: version)
            let data = try JSONEncoder().encode(backupSession)
            backup(data: data) { (result) in
                do {
                    if result {
                        // Occurs if backup failed earlier, but succeeded now: delete sharedSeed from Keychain
                        if keychainSeed != nil {
                            try Keychain.shared.delete(id: SessionIdentifier.sharedSeed.identifier(for: self.id), service: .signingTeamSessionKey)
                        }
                    } else {
                        // Occurs if backup failed now, so we can try next time
                        if keychainSeed == nil {
                            try Keychain.shared.save(id: SessionIdentifier.sharedSeed.identifier(for: self.id), service: .signingTeamSessionKey, secretData: seed)
                        }
                    }
                } catch {
                    Logger.shared.error("Error updating team session backup state", error: error)
                }
                group?.leave()
            }
        } catch {
            Logger.shared.error("Error updating team session backup state", error: error)
            group?.leave()
        }

    }

}

fileprivate struct BackupTeamSession: Codable {
    let id: String
    let seed: Data
    let title: String
    let version: Int
}
