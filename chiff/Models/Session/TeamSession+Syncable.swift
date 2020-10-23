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

    static func all(context: LAContext?) throws -> [String: TeamSession] {
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
        teamId = backupSession.teamId
        signingPubKey = signingKeyPair.pubKey.base64
        title = backupSession.title
        version = backupSession.version
        isAdmin = false
        created = true
        lastChange = Date.now
        organisationKey = backupSession.organisationKey

        try save(sharedSeed: backupSession.seed, key: encryptionKey, signingKeyPair: signingKeyPair, passwordSeed: passwordSeed, sharedKeyPrivKey: backupSession.privKey)
    }

    mutating func update(with backupObject: BackupTeamSession, context: LAContext?) throws -> Bool {
        var newSeed: Data?
        if let seed = try Keychain.shared.get(id: SessionIdentifier.sharedSeed.identifier(for: self.id), service: Self.signingService), !Crypto.shared.equals(first: backupObject.seed, second: seed) {
            newSeed = backupObject.seed
        }
        if backupObject.title != title {
            title = backupObject.title
        } else if newSeed == nil {
            // Nothing has changed
            return false
        }
        lastChange = backupObject.lastChange
        let sessionData = try PropertyListEncoder().encode(self as Self)
        if let seed = newSeed {
            let (passwordSeed, encryptionKey, signingKeyPair) = try TeamSession.createTeamSessionKeys(seed: seed)
            try Keychain.shared.update(id: SessionIdentifier.sharedKey.identifier(for: self.id), service: Self.encryptionService, secretData: encryptionKey, objectData: sessionData)
            try Keychain.shared.update(id: SessionIdentifier.signingKeyPair.identifier(for: id), service: Self.signingService, secretData: signingKeyPair.privKey)
            try Keychain.shared.update(id: SessionIdentifier.passwordSeed.identifier(for: id), service: Self.signingService, secretData: passwordSeed)
            try Keychain.shared.update(id: SessionIdentifier.sharedSeed.identifier(for: id), service: Self.signingService, secretData: seed)
        } else {
            try Keychain.shared.update(id: SessionIdentifier.sharedKey.identifier(for: id), service: Self.encryptionService, objectData: sessionData)
        }
        return true
    }

    func deleteSync() throws {
        // TeamSession shouldn't be deleted based on user backup sync, so this is not implemented.
    }

    func backup() -> Promise<Void> {
        do {
            guard let seed = try Keychain.shared.get(id: SessionIdentifier.sharedSeed.identifier(for: self.id), service: TeamSession.signingService), created else {
                return .value(())
            }
            guard let privKey = try Keychain.shared.get(id: SessionIdentifier.sharedKeyPrivKey.identifier(for: self.id), service: TeamSession.signingService), created else {
                return .value(())
            }
            return firstly {
                sendData(item: BackupTeamSession(id: id,
                                                 teamId: teamId,
                                                 seed: seed,
                                                 title: title,
                                                 version: version,
                                                 lastChange: lastChange,
                                                 creationDate: creationDate,
                                                 organisationKey: organisationKey,
                                                 privKey: privKey))
            }.log("Error updating team session backup state")
        } catch {
            Logger.shared.error("Error updating team session backup state", error: error)
            return Promise(error: error)
        }
    }

}

struct BackupTeamSession: BackupObject {
    let id: String
    let teamId: String
    let seed: Data
    let privKey: Data
    let title: String
    let version: Int
    var lastChange: Timestamp
    let creationDate: Timestamp
    let organisationKey: Data

    enum CodingKeys: CodingKey {
        case id
        case teamId
        case seed
        case privKey
        case title
        case version
        case lastChange
        case creationDate
        case organisationKey
    }

    init(id: String, teamId: String, seed: Data, title: String, version: Int, lastChange: Timestamp, creationDate: Date, organisationKey: Data, privKey: Data) {
        self.id = id
        self.teamId = teamId
        self.seed = seed
        self.privKey = privKey
        self.title = title
        self.version = version
        self.lastChange = lastChange
        self.creationDate = creationDate.millisSince1970
        self.organisationKey = organisationKey
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try values.decode(String.self, forKey: .id)
        self.teamId = try values.decode(String.self, forKey: .teamId)
        self.seed = try values.decode(Data.self, forKey: .seed)
        self.title = try values.decode(String.self, forKey: .title)
        self.version = try values.decodeIfPresent(Int.self, forKey: .version) ?? 0
        self.lastChange = try values.decodeIfPresent(Timestamp.self, forKey: .lastChange) ?? 0
        self.creationDate = try values.decodeIfPresent(Timestamp.self, forKey: .creationDate) ?? Date.now
        self.organisationKey = try values.decode(Data.self, forKey: .organisationKey)
        self.privKey = try values.decode(Data.self, forKey: .privKey)
    }
}
