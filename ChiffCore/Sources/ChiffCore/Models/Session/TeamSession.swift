//
//  TeamSession.swift
//  ChiffCore
//
//  Copyright: see LICENSE.md
//

#if canImport(UIKit)
import UIKit
#else
import Cocoa
#endif
import UserNotifications
import LocalAuthentication
import PromiseKit

public enum TeamSessionError: Error {
    case adminDelete
    case logoPathNotFound
    case notAdmin
    case alreadyCreated
}

public enum OrganisationType: Int, Codable {
    case team
    case enterprise
}

/// A session with a Chiff Team.
public struct TeamSession: Session {
    public let creationDate: Date
    public let id: String
    public var signingPubKey: String
    public let teamId: String
    var created: Bool
    public var isAdmin: Bool
    public var version: Int
    public var title: String
    public var lastChange: Timestamp
    public let organisationKey: Data
    var type: OrganisationType = .team
    var logoPath: String? {
        let filemgr = FileManager.default
        return filemgr.urls(for: .libraryDirectory, in: .userDomainMask).first?.appendingPathComponent("team_logo_\(id).png").path
    }
    #if canImport(UIKit)
    public var logo: UIImage? {
        guard let path = logoPath else {
            return nil
        }
        return UIImage(contentsOfFile: path)
    }
    #else
    public var logo: NSImage? {
        guard let path = logoPath else {
            return nil
        }
        return NSImage(contentsOfFile: path)
    }
    #endif

    public var accountCount: Int {
        return Properties.getSharedAccountCount(teamId: id)
    }

    static let cryptoContext = "keynteam"
    public static var signingService: KeychainService = .teamSession(attribute: .signing)
    public static var encryptionService: KeychainService = .teamSession(attribute: .shared)
    public static var sessionCountFlag: String = "teamSessionCount"

    /// Initialize a `TeamSession`.
    /// - Parameters:
    ///   - id: The session id.
    ///   - teamId: The team id.
    ///   - signingPubKey: The signing pubkey.
    ///   - title: The title of the session. Just for internal display.
    ///   - version: The session version.
    ///   - isAdmin: Whether this user is admin of this team.
    ///   - created: Whether the session has been remotely created.
    ///         During the pairing process, the QR-code is scanned, at which the session is created at the phone.
    ///         However, it may still be be cancelled there in the UI.
    ///   - lastChange: A timestamp of the last change, used for syncing.
    ///   - organisationKey: The organisation key that this teams belongs to. Used to retrieve organisation PPDs and logo.
    public init(id: String, teamId: String, signingPubKey: Data, title: String, version: Int, isAdmin: Bool, created: Bool = false, lastChange: Timestamp, organisationKey: Data) {
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

    /// Primary function to intiate a team session, usually called by scanning a QR-code.
    /// - Parameters:
    ///   - pairingQueueSeed: The pairing queue seed.
    ///   - teamId: The team id.
    ///   - browserPubKey: The team's public key to establish the shared key.
    ///   - role: The role this user has in the team.
    ///   - team: The name of the team / organisation.
    ///   - version: The session version.
    ///   - organisationKey: The organisation key of the organisation this team belongs to.
    /// - Returns: A Promise of the session that is created.
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

    /// Return the organisation `KeyPair`.
    /// - Throws: Crypto or Keychain errors.
    /// - Returns: The organisation `KeyPair`.
    public static func organisationKeyPair() throws -> KeyPair? {
        guard let organisationKey = try TeamSession.all().first?.organisationKey else {
            return nil
        }
        return try Crypto.shared.createSigningKeyPair(seed: organisationKey)
    }

    /// Save this session to the Keychain and update remotely, if necessary.
    /// - Parameter makeBackup: Whether a remote backup should be made.
    /// - Throws: Encoding or Keychain errors.
    public mutating func update(makeBackup: Bool) throws {
        if makeBackup {
            lastChange = Date.now
        }
        let sessionData = try PropertyListEncoder().encode(self as Self)
        try Keychain.shared.update(id: SessionIdentifier.sharedKey.identifier(for: id), service: Self.encryptionService, objectData: sessionData)
        if makeBackup {
            _ = backup()
        }
    }

    // Documentation in protocol.
    public func delete(notify: Bool) -> Promise<Void> {
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

    /// Delete data from the Keychain.
    /// - Parameter backup: If this is true (default), backup will be deleted as well.
    /// - Throws: Keychain errors.
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

    /// Save the team session keys to the Keychain.
    /// - Parameter keys: The `TeamSessionKeys`.
    /// - Throws: Keychain or encoding errors.
    public func save(keys: TeamSessionKeys) throws {
        try keys.save(id: self.id, data: PropertyListEncoder().encode(self))
    }

    /// Save the team seeds.
    /// - Parameters:
    ///   - keys: The team seeds that should be saved.
    ///   - privKey: The private key, only used in case of admin revocation.
    /// - Throws: Keychain errors.
    func save(keys: TeamSessionSeeds, privKey: Data) throws {
        try keys.save(id: self.id, privKey: privKey, data: PropertyListEncoder().encode(self))
    }

    /// Retrieve the password seed from the Keychain.
    /// - Throws: Keychain errors
    /// - Returns: The password seed.
    func passwordSeed() throws -> Data {
        guard let seed = try Keychain.shared.get(id: SessionIdentifier.passwordSeed.identifier(for: id), service: Self.signingService) else {
            throw KeychainError.notFound
        }
        return seed
    }

    /// Submit an account to the team.
    /// - Parameter account: The account the user wants to share with the team.
    public func submitAccountToTeam(account: UserAccount) -> Promise<Void> {
        do {
            let passwordGenerator = PasswordGenerator(username: account.username, siteId: account.sites[0].id, ppd: account.sites[0].ppd, passwordSeed: try passwordSeed())
            var offset: [Int]?
            if let password = try account.password() {
                offset = try passwordGenerator.calculateOffset(index: 0, password: password)
            }
            let token = try account.oneTimePasswordToken()
            let newAccount = BackupSharedAccount(
                id: account.id,
                username: account.username,
                sites: account.sites,
                passwordIndex: 0,
                passwordOffset: offset,
                tokenURL: try token?.toURL(),
                tokenSecret: token?.generator.secret,
                version: account.version,
                notes: try account.notes())
            let data = try JSONEncoder().encode(newAccount)
            let message: [String: Any] = [
                "data": try Crypto.shared.encrypt(data, key: self.sharedKey()).base64
            ]
            return API.shared.signedRequest(path: "teams/users/\(teamId)/\(id)/accounts/\(account.id)", method: .post, privKey: try signingPrivKey(), message: message).asVoid()
        } catch {
            return Promise(error: error)
        }
    }

    // MARK: - Admin functions

    /// Retrieve the team seed remotely aand decrypt it.
    /// - Returns: A promise of the team seed.
    public func getTeamSeed() -> Promise<Data> {
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

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
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
