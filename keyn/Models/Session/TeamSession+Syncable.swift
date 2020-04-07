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
        let session = try TeamSession(from: backupObject, context: context)
        _ = updateTeamSession(session: session).catch { error in
            Logger.shared.warning("Failed to update shared accounts after creating team session from backup", error: error)
        }
    }

    static func notifyObservers() {
        NotificationCenter.default.postMain(name: .sessionUpdated, object: self)
    }

    init(from backupSession: BackupTeamSession, context: LAContext?) throws {
        let (passwordSeed, encryptionKey, signingKeyPair) = try TeamSession.createTeamSessionKeys(seed: backupSession.seed)
        creationDate = Date(millisSince1970: backupSession.creationDate)
        id = backupSession.id
        signingPubKey = signingKeyPair.pubKey.base64
        title = backupSession.title
        version = backupSession.version
        isAdmin = false
        created = true
        lastChange = Date.now
        try save(sharedSeed: backupSession.seed, key: encryptionKey, signingKeyPair: signingKeyPair, passwordSeed: passwordSeed)
    }

    mutating func update(with backupObject: BackupTeamSession, context: LAContext?) throws -> Bool {
        guard backupObject.title != title else {
            return false
        }
        lastChange = backupObject.lastChange
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
                return .value(())
            }
            return firstly {
                sendData(item: BackupTeamSession(id: id, seed: seed, title: title, version: version, lastChange: lastChange, creationDate: creationDate))
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
    var lastChange: Timestamp
    let creationDate: Timestamp

    enum CodingKeys: CodingKey {
        case id
        case seed
        case title
        case version
        case lastChange
        case creationDate
    }

    init(id: String, seed: Data, title: String, version: Int, lastChange: Timestamp, creationDate: Date) {
        self.id = id
        self.seed = seed
        self.title = title
        self.version = version
        self.lastChange = lastChange
        self.creationDate = creationDate.millisSince1970
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try values.decode(String.self, forKey: .id)
        self.seed = try values.decode(Data.self, forKey: .seed)
        self.title = try values.decode(String.self, forKey: .title)
        self.version = try values.decodeIfPresent(Int.self, forKey: .version) ?? 0
        self.lastChange = try values.decodeIfPresent(Timestamp.self, forKey: .lastChange) ?? 0
        self.creationDate = try values.decodeIfPresent(Timestamp.self, forKey: .creationDate) ?? Date.now
    }
}
