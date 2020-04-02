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

extension TeamSession: Syncable {

    typealias BackupType = BackupTeamSession

    static var syncEndpoint: SyncEndpoint {
        return .sessions
    }

    static func all(context: LAContext?) throws -> [String : TeamSession] {
        return try Dictionary(uniqueKeysWithValues: all().map { ($0.id, $0) })
    }

    static func create(backupObject: BackupTeamSession, context: LAContext?) throws {
        let _ = try TeamSession(from: backupObject, context: context)
    }

    static func notifyObservers() {
        NotificationCenter.default.postMain(name: .sessionUpdated, object: self)
    }

    init(from backupSession: BackupTeamSession, context: LAContext?) throws {
        let (passwordSeed, encryptionKey, signingKeyPair) = try TeamSession.createTeamSessionKeys(seed: backupSession.seed)
        creationDate = Date()
        id = backupSession.id
        signingPubKey = signingKeyPair.pubKey.base64
        title = backupSession.title
        version = backupSession.version
        isAdmin = false
        created = true
        lastChange = Date.now
        try save(key: encryptionKey, signingKeyPair: signingKeyPair, passwordSeed: passwordSeed)
    }

    mutating func update(with backupObject: BackupTeamSession, context: LAContext?) throws -> Bool {
        guard backupObject.title != title else {
            return false
        }
        lastChange = Date.now
        title = backupObject.title
        try update(makeBackup: false)
        return true
    }

    func deleteSync() throws {
        // TeamSession shouldn't be deleted based on user backup sync, so this is not implemented.
    }

    func backup() -> Promise<Void> {
        do {
            guard let seed = try Keychain.shared.get(id: SessionIdentifier.sharedSeed.identifier(for: self.id), service: .signingTeamSessionKey), created else {
                // Backup complete
                return .value(())
            }
            return firstly {
                sendData(item: BackupTeamSession(id: id, seed: seed, title: title, version: version))
            }.map { _ in
                try Keychain.shared.setSynced(value: true, id: SessionIdentifier.sharedSeed.identifier(for: self.id), service: .signingTeamSessionKey)
            }.recover { error in
                try Keychain.shared.setSynced(value: false, id: SessionIdentifier.sharedSeed.identifier(for: self.id), service: .signingTeamSessionKey)
                throw error
            }.log("Error updating team session backup state")
        } catch {
            Logger.shared.error("Error updating team session backup state", error: error)
            return Promise(error: error)
        }

    }

}

struct BackupTeamSession: BackupObject {
    let id: String
    let seed: Data
    let title: String
    let version: Int
    var lastChange: TimeInterval

    enum CodingKeys: CodingKey {
        case id
        case seed
        case title
        case version
        case lastChange
    }

    init(id: String, seed: Data, title: String, version: Int) {
        self.id = id
        self.seed = seed
        self.title = title
        self.version = version
        self.lastChange = Date.now
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try values.decode(String.self, forKey: .id)
        self.seed = try values.decode(Data.self, forKey: .id)
        self.title = try values.decode(String.self, forKey: .id)
        self.version = try values.decodeIfPresent(Int.self, forKey: .version) ?? 0
        self.lastChange = try values.decodeIfPresent(TimeInterval.self, forKey: .lastChange) ?? Date.now
    }
}
