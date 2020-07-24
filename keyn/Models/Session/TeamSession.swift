/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
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
    let signingPubKey: String
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

    static let CRYPTO_CONTEXT = "keynteam"
    static var signingService: KeychainService = .signingTeamSessionKey
    static var encryptionService: KeychainService = .sharedTeamSessionKey
    static var sessionCountFlag: String = "teamSessionCount"

    init(id: String, signingPubKey: Data, title: String, version: Int, isAdmin: Bool, created: Bool = false, lastChange: Timestamp, organisationKey: Data) {
        self.creationDate = Date()
        self.id = id
        self.signingPubKey = signingPubKey.base64
        self.version = version
        self.title = title
        self.isAdmin = isAdmin
        self.created = created
        self.lastChange = lastChange
        self.organisationKey = organisationKey
    }

    // MARK: - Static functions

    static func organisationKeyPair() throws -> KeyPair? {
        guard let organisationKey = try TeamSession.all().first?.organisationKey else {
            return nil
        }
        return try Crypto.shared.createSigningKeyPair(seed: organisationKey)
    }

    static func initiate(pairingQueueSeed: String, browserPubKey: String, role: String, team: String, version: Int, organisationKey: String) -> Promise<Session> {
        do {
            let browserPubKeyData = try Crypto.shared.convertFromBase64(from: browserPubKey)
            let organisationKeyData = try Crypto.shared.convertFromBase64(from: organisationKey)
            let keyPairForSharedKey = try Crypto.shared.createSessionKeyPair()
            let sharedSeed = try Crypto.shared.generateSharedKey(pubKey: browserPubKeyData, privKey: keyPairForSharedKey.privKey)
            let (passwordSeed, encryptionKey, signingKeyPair) = try createTeamSessionKeys(seed: sharedSeed)
            let pairingKeyPair = try Crypto.shared.createSigningKeyPair(seed: Crypto.shared.convertFromBase64(from: pairingQueueSeed)) // Used for pairing
            let session = TeamSession(id: browserPubKey.hash, signingPubKey: signingKeyPair.pubKey, title: "\(role) @ \(team)", version: 2, isAdmin: false, lastChange: Date.now, organisationKey: organisationKeyData)
            return firstly {
                try session.acknowledgeSessionStart(pairingKeyPair: pairingKeyPair, browserPubKey: browserPubKeyData, sharedKeyPubkey: keyPairForSharedKey.pubKey.base64)
            }.map { _ in
                do {
                    try session.save(sharedSeed: sharedSeed, key: encryptionKey, signingKeyPair: signingKeyPair, passwordSeed: passwordSeed)
                    TeamSession.count += 1
                    NotificationCenter.default.postMain(name: .subscriptionUpdated, object: nil, userInfo: ["status": Properties.hasValidSubscription])
                    return session
                } catch is KeychainError {
                    throw SessionError.exists
                } catch is CryptoError {
                    throw SessionError.invalid
                }
            }
            // TODO: Update existing browser sessions.
        } catch {
            Logger.shared.error("Error initiating session", error: error)
            return Promise(error: error)
        }
    }

    static func createTeamSessionKeys(seed: Data) throws -> (Data, Data, KeyPair) {
        let passwordSeed =  try Crypto.shared.deriveKey(keyData: seed, context: CRYPTO_CONTEXT, index: 0) // Used to generate passwords
        let encryptionKey = try Crypto.shared.deriveKey(keyData: seed, context: CRYPTO_CONTEXT, index: 1) // Used to encrypt messages for this session
        let signingKeyPair = try Crypto.shared.createSigningKeyPair(seed: Crypto.shared.deriveKey(keyData: seed, context: CRYPTO_CONTEXT, index: 2)) // Used to sign messages for the server
        return (passwordSeed, encryptionKey, signingKeyPair)
    }

    static func updateAllTeamSessions(pushed: Bool, pubKeys: [String]? = nil) -> Promise<Void> {
        return firstly {
            when(fulfilled: try TeamSession.all().compactMap { session -> Promise<Bool>? in
                if let pubKeys = pubKeys {
                    guard pubKeys.contains(session.signingPubKey) else {
                         return nil
                    }
                }
                return updateTeamSession(session: session, pushed: pushed)
           })
        }.map { results in
            if results.reduce(false, { $0 ? $0 : $1 }) {
                let teamSessions = try TeamSession.all()
                let organisationKey = teamSessions.first?.organisationKey
                let organisationType = teamSessions.first?.type
                let isAdmin = teamSessions.contains(where: { $0.isAdmin })
                BrowserSession.updateAllSessionData(organisationKey: organisationKey, organisationType: organisationType, isAdmin: isAdmin)
            }
        }.asVoid()
    }

    static func updateTeamSession(session: TeamSession, pushed: Bool = false) -> Promise<Bool> {
        var session = session
        var created = false
        var changed = false
        if !session.created && pushed {
            session.created = true
            changed = true
            created = true
        }
        return firstly {
            when(fulfilled: session.getOrganisationData(), API.shared.signedRequest(method: .get, message: nil, path: "teams/users/\(session.signingPubKey)", privKey: try session.signingPrivKey(), body: nil, parameters: nil))
        }.map { (type, result) in
            guard let accounts = result["accounts"] as? [String: String] else {
                throw CodingError.missingData
            }
            guard let isAdmin = result["admin"] as? Bool else {
                throw CodingError.missingData
            }
            if let type = type, session.type != type {
                session.type = type
                changed = true
            }
            if session.isAdmin != isAdmin {
                session.isAdmin = isAdmin
                changed = true
            }
            if changed {
                try session.update(makeBackup: created)
            }
            let updatedAccounts = try session.updateSharedAccounts(accounts: accounts)
            if changed || updatedAccounts > 0 {
                NotificationCenter.default.postMain(name: .sharedAccountsChanged, object: nil)
                NotificationCenter.default.postMain(name: .sessionUpdated, object: nil, userInfo: ["session": session, "count": accounts.count])
            }
            return changed
        }.recover { (error) -> Promise<Bool> in
            guard case APIError.statusCode(404) = error else {
                throw error
            }
            guard session.created else {
                return .value(false)
            }
            try? session.delete()
            NotificationCenter.default.postMain(name: .sessionEnded, object: nil, userInfo: [NotificationContentKey.sessionId: session.id])
            NotificationCenter.default.postMain(name: .sharedAccountsChanged, object: nil)
            return .value(true)
        }
    }

    mutating func updateSharedAccounts(accounts: [String: String]) throws -> Int {
        var changed = 0
        let key = try self.passwordSeed()
        #warning("TODO: If an account already exists because of an earlier session, now throws keyn.KeychainError.unhandledError(-25299). Handle better")
        var currentAccounts = try SharedAccount.all(context: nil, label: self.signingPubKey)
        for (id, data) in accounts {
            currentAccounts.removeValue(forKey: id)
            let ciphertext = try Crypto.shared.convertFromBase64(from: data)
            let (accountData, _)  = try Crypto.shared.decrypt(ciphertext, key: self.sharedKey(), version: self.version)
            if var account = try SharedAccount.get(id: id, context: nil) {
                if try account.sync(accountData: accountData, key: key) {
                    changed += 1
                }
            } else { // New account added
                try SharedAccount.create(accountData: accountData, id: id, key: key, context: nil, sessionPubKey: self.signingPubKey)
                changed += 1
            }
        }
        for account in currentAccounts.values {
            #warning("Check how to safely delete here in the background")
            try account.deleteSync()
            changed += 1
        }
        Properties.setSharedAccountCount(teamId: self.id, count: accounts.count)
        return changed
    }

    func acknowledgeSessionStart(pairingKeyPair: KeyPair, browserPubKey: Data, sharedKeyPubkey: String) throws -> Promise<Void> {
        guard let endpoint = Properties.endpoint else {
            throw SessionError.noEndpoint
        }
        let pairingResponse = KeynTeamPairingResponse(sessionID: id, pubKey: sharedKeyPubkey, browserPubKey: browserPubKey.base64, userID: Properties.userId!, environment: Properties.migrated ? Properties.Environment.prod.rawValue : Properties.environment.rawValue, type: .pair, version: version, userPubKey: try Seed.publicKey(), arn: endpoint)
        let jsonPairingResponse = try JSONEncoder().encode(pairingResponse)
        let ciphertext = try Crypto.shared.encrypt(jsonPairingResponse, pubKey: browserPubKey)
        let signedCiphertext = try Crypto.shared.sign(message: ciphertext, privKey: pairingKeyPair.privKey)
        let message = [
            "data": signedCiphertext.base64
        ]
        let jsonData = try JSONSerialization.data(withJSONObject: message, options: [])
        return API.shared.signedRequest(method: .put, message: nil, path: "sessions/\(pairingKeyPair.pubKey.base64)/pairing", privKey: pairingKeyPair.privKey, body: jsonData, parameters: nil).asVoid().log("Error sending pairing response.")
    }

    mutating func update(makeBackup: Bool) throws {
        if makeBackup {
            lastChange = Date.now
        }
        let sessionData = try PropertyListEncoder().encode(self as Self)
        try Keychain.shared.update(id: SessionIdentifier.sharedKey.identifier(for: id), service: Self.encryptionService, objectData: sessionData)
        if makeBackup {
            let _ = backup()
        }
    }

    func delete(notify: Bool) -> Promise<Void> {
        return firstly {
            API.shared.signedRequest(method: .delete, message: nil, path: "teams/users/\(signingPubKey)", privKey: try signingPrivKey(), body: nil, parameters: nil)
        }.asVoid().recover { error -> Void in
            if case APIError.statusCode(404) = error {
                try self.delete()
                return
            } else {
                throw error
            }
        }.log("Error deleting arn for team session")
    }

    func delete(ifNotCreated: Bool = false, backup: Bool = true) throws {
        if ifNotCreated && created {
            throw TeamSessionError.alreadyCreated
        }
        SharedAccount.deleteAll(for: self.signingPubKey)
        try Keychain.shared.delete(id: SessionIdentifier.sharedKey.identifier(for: id), service: TeamSession.encryptionService)
        try Keychain.shared.delete(id: SessionIdentifier.signingKeyPair.identifier(for: id), service: TeamSession.signingService)
        try Keychain.shared.delete(id: SessionIdentifier.passwordSeed.identifier(for: id), service: TeamSession.signingService)
        TeamSession.count -= 1
        NotificationCenter.default.postMain(name: .subscriptionUpdated, object: nil, userInfo: ["status": Properties.hasValidSubscription])
        if backup {
            try deleteBackup()
        }
    }

    func save(sharedSeed: Data, key: Data, signingKeyPair: KeyPair, passwordSeed: Data) throws {
        let sessionData = try PropertyListEncoder().encode(self)
        try Keychain.shared.save(id: SessionIdentifier.sharedKey.identifier(for: id), service: TeamSession.encryptionService, secretData: key, objectData: sessionData)
        try Keychain.shared.save(id: SessionIdentifier.signingKeyPair.identifier(for: id), service: TeamSession.signingService, secretData: signingKeyPair.privKey)
        try Keychain.shared.save(id: SessionIdentifier.passwordSeed.identifier(for: id), service: TeamSession.signingService, secretData: passwordSeed)
        try Keychain.shared.save(id: SessionIdentifier.sharedSeed.identifier(for: id), service: TeamSession.signingService, secretData: sharedSeed)
    }

    func passwordSeed() throws -> Data {
        guard let seed = try Keychain.shared.get(id: SessionIdentifier.passwordSeed.identifier(for: id), service: TeamSession.signingService) else {
            throw KeychainError.notFound
        }
        return seed
    }

    func getOrganisationData() -> Promise<OrganisationType?> {
        let filemgr = FileManager.default
        guard let path = logoPath else {
            return Promise(error: TeamSessionError.logoPathNotFound)
        }
        return firstly { () -> Promise<JSONObject> in
            let organisationKeyPair = try Crypto.shared.createSigningKeyPair(seed: organisationKey)
            return API.shared.signedRequest(method: .get, message: nil, path: "organisations/\(organisationKeyPair.pubKey.base64)", privKey: organisationKeyPair.privKey, body: nil, parameters: nil)
        }.map { result in
            if let logo = result["logo"] as? String {
                guard let data = Data(base64Encoded: logo, options: .ignoreUnknownCharacters), let _ = UIImage(data: data) else {
                    throw CodingError.unexpectedData
                }
                if filemgr.fileExists(atPath: path) {
                    try filemgr.removeItem(atPath: path)
                }
                filemgr.createFile(atPath: path, contents: data, attributes: nil)
            }
            if let typeValue = result["type"] as? Int, let type = OrganisationType(rawValue: typeValue) {
                return type
            } else {
                return nil
            }
        }.recover { (error) -> Promise<OrganisationType?> in
            return .value(nil)
        }
    }

    // MARK: - Admin functions

    func getTeamSeed() -> Promise<Data> {
        return firstly {
            API.shared.signedRequest(method: .get, message: nil, path: "teams/users/\(signingPubKey)/admin", privKey: try signingPrivKey(), body: nil, parameters: nil)
        }.map { result in
            guard let teamSeed = result["team_seed"] as? String else {
                throw CodingError.unexpectedData
            }
            let ciphertext = try Crypto.shared.convertFromBase64(from: teamSeed)
            let (seed, _) = try Crypto.shared.decrypt(ciphertext, key: self.sharedKey(), version: self.version)
            return seed
        }.log("Error getting admin seed")
    }

}

extension TeamSession: Codable {

    enum CodingKeys: CodingKey {
        case creationDate
        case id
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
