//
//  TeamSession.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import UIKit
import UserNotifications
import LocalAuthentication
import PromiseKit

enum TeamSessionError: Error {
    case adminDelete
    case logoPathNotFound
    case notAdmin
    case alreadyCreated
}

enum OrganisationType: Int, Codable {
    case team
    case enterprise
}

struct TeamSession: Session {
    var backgroundTask: Int = UIBackgroundTaskIdentifier.invalid.rawValue
    let creationDate: Date
    let id: String
    var signingPubKey: String
    let teamId: String
    var created: Bool
    var isAdmin: Bool
    var version: Int
    var title: String
    var lastChange: Timestamp
    let organisationKey: Data
    var type: OrganisationType = .team
    var logoPath: String? {
        let filemgr = FileManager.default
        return filemgr.urls(for: .libraryDirectory, in: .userDomainMask).first?.appendingPathComponent("team_logo_\(id).png").path
    }
    var logo: UIImage? {
        guard let path = logoPath else {
            return nil
        }
        return UIImage(contentsOfFile: path)
    }
    var accountCount: Int {
        return Properties.getSharedAccountCount(teamId: id)
    }

    static let cryptoContext = "keynteam"
    static var signingService: KeychainService = .teamSession(attribute: .signingKey)
    static var encryptionService: KeychainService = .teamSession(attribute: .sharedKey)
    static var sessionCountFlag: String = "teamSessionCount"

    init(id: String, teamId: String, signingPubKey: Data, title: String, version: Int, isAdmin: Bool, created: Bool = false, lastChange: Timestamp, organisationKey: Data) {
        self.creationDate = Date()
        self.id = id
        self.teamId = teamId
        self.signingPubKey = signingPubKey.base64
        self.version = version
        self.title = title
        self.isAdmin = isAdmin
        self.created = created
        self.lastChange = lastChange
        self.organisationKey = organisationKey
    }

    // MARK: - Static functions

    static func initiate(pairingQueueSeed: String, teamId: String, browserPubKey: String, role: String, team: String, version: Int, organisationKey: String) -> Promise<Session> {
        do {
            let keys = try TeamSessionKeys(browserPubKey: browserPubKey)
            let organisationKeyData = try Crypto.shared.convertFromBase64(from: organisationKey)
            let pairingKeyPair = try Crypto.shared.createSigningKeyPair(seed: Crypto.shared.convertFromBase64(from: pairingQueueSeed)) // Used for pairing
            let session = TeamSession(id: keys.sessionId,
                                      teamId: teamId,
                                      signingPubKey: keys.signingKeyPair.pubKey,
                                      title: "\(role) @ \(team)",
                                      version: 2,
                                      isAdmin: false,
                                      lastChange: Date.now,
                                      organisationKey: organisationKeyData)
            let response = try TeamPairingResponse(id: session.id, pubKey: keys.pubKey, browserPubKey: browserPubKey, version: session.version)
            return firstly {
                session.acknowledgeSessionStart(pairingKeyPair: pairingKeyPair, browserPubKey: keys.browserPubKey, pairingResponse: response)
            }.map { _ in
                do {
                    try session.save(keys: keys)
                    TeamSession.count += 1
                } catch is KeychainError {
                    throw SessionError.exists
                } catch is CryptoError {
                    throw SessionError.invalid
                }
            }.then {
                BrowserSession.updateAllSessionData(organisationKey: organisationKeyData, organisationType: .team, isAdmin: true).map { session }
            }
        } catch {
            Logger.shared.error("Error initiating session", error: error)
            return Promise(error: error)
        }
    }

    static func organisationKeyPair() throws -> KeyPair? {
        guard let organisationKey = try TeamSession.all().first?.organisationKey else {
            return nil
        }
        return try Crypto.shared.createSigningKeyPair(seed: organisationKey)
    }

    mutating func update(makeBackup: Bool) throws {
        if makeBackup {
            lastChange = Date.now
        }
        let sessionData = try PropertyListEncoder().encode(self as Self)
        try Keychain.shared.update(id: SessionIdentifier.sharedKey.identifier(for: id), service: Self.encryptionService, objectData: sessionData)
        if makeBackup {
            _ = backup()
        }
    }

    func delete(notify: Bool) -> Promise<Void> {
        return firstly {
            API.shared.signedRequest(path: "teams/users/\(teamId)/\(id)", method: .delete, privKey: try signingPrivKey())
        }.map { _ in
            try self.delete()
        }.asVoid().recover { error -> Void in
            if case APIError.statusCode(404) = error {
                try self.delete()
                return
            } else {
                throw error
            }
        }.log("Error deleting arn for team session")
    }

    func delete(backup: Bool = true) throws {
        SharedAccount.deleteAll(for: self.id)
        try Keychain.shared.delete(id: SessionIdentifier.sharedKey.identifier(for: id), service: Self.encryptionService)
        try Keychain.shared.delete(id: SessionIdentifier.sharedSeed.identifier(for: id), service: Self.signingService)
        try Keychain.shared.delete(id: SessionIdentifier.signingKeyPair.identifier(for: id), service: Self.signingService)
        try Keychain.shared.delete(id: SessionIdentifier.passwordSeed.identifier(for: id), service: Self.signingService)
        try Keychain.shared.delete(id: SessionIdentifier.sharedKeyPrivKey.identifier(for: id), service: Self.signingService)
        TeamSession.count -= 1
        if backup {
            _ = deleteBackup()
        }
    }

    func save(keys: TeamSessionKeys) throws {
        try keys.save(id: self.id, data: PropertyListEncoder().encode(self))
    }

    func save(keys: TeamSessionSeeds, privKey: Data) throws {
        try keys.save(id: self.id, privKey: privKey, data: PropertyListEncoder().encode(self))
    }

    func passwordSeed() throws -> Data {
        guard let seed = try Keychain.shared.get(id: SessionIdentifier.passwordSeed.identifier(for: id), service: Self.signingService) else {
            throw KeychainError.notFound
        }
        return seed
    }

    // MARK: - Admin functions

    func getTeamSeed() -> Promise<Data> {
        return firstly {
            API.shared.signedRequest(path: "teams/users/\(teamId)/\(id)/admin", method: .get, privKey: try signingPrivKey())
        }.map { result in
            guard let teamSeed = result["team_seed"] as? String else {
                throw CodingError.unexpectedData
            }
            let ciphertext = try Crypto.shared.convertFromBase64(from: teamSeed)
            let seed = try Crypto.shared.decrypt(ciphertext, key: self.sharedKey(), version: self.version)
            return seed
        }.log("Error getting admin seed")
    }

    func getTeam() -> Promise<Team> {
        return firstly {
            getTeamSeed()
        }.then { seed in
            Team.get(id: self.teamId, seed: seed)
        }
    }

}

extension TeamSession: Codable {

    enum CodingKeys: CodingKey {
        case creationDate
        case id
        case teamId
        case signingPubKey
        case created
        case isAdmin
        case version
        case title
        case lastChange
        case organisationKey
        case type
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.backgroundTask = UIBackgroundTaskIdentifier.invalid.rawValue
        self.id = try values.decode(String.self, forKey: .id)
        self.teamId = try values.decode(String.self, forKey: .teamId)
        self.creationDate = try values.decode(Date.self, forKey: .creationDate)
        self.signingPubKey = try values.decode(String.self, forKey: .signingPubKey)
        self.created = try values.decode(Bool.self, forKey: .created)
        self.isAdmin = try values.decode(Bool.self, forKey: .isAdmin)
        self.version = try values.decode(Int.self, forKey: .version)
        self.title = try values.decode(String.self, forKey: .title)
        self.lastChange = try values.decodeIfPresent(Timestamp.self, forKey: .lastChange) ?? 0
        self.organisationKey = try values.decode(Data.self, forKey: .organisationKey)
        self.type = try values.decodeIfPresent(OrganisationType.self, forKey: .type) ?? .team
    }
}
