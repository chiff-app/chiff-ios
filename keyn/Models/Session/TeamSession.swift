/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit
import UserNotifications
import LocalAuthentication
import PromiseKit

enum TeamSessionError: KeynError {
    case adminDelete
    case logoPathNotFound
    case notAdmin
    case alreadyCreated
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

    init(id: String, signingPubKey: Data, title: String, version: Int, isAdmin: Bool, created: Bool = false) {
        self.creationDate = Date()
        self.id = id
        self.signingPubKey = signingPubKey.base64
        self.version = version
        self.title = title
        self.isAdmin = isAdmin
        self.created = created
    }

    // MARK: - Static functions

    static func initiate(pairingQueueSeed: String, browserPubKey: String, role: String, team: String, version: Int) -> Promise<Session> {
        do {
            let browserPubKeyData = try Crypto.shared.convertFromBase64(from: browserPubKey)
            let keyPairForSharedKey = try Crypto.shared.createSessionKeyPair()
            let sharedSeed = try Crypto.shared.generateSharedKey(pubKey: browserPubKeyData, privKey: keyPairForSharedKey.privKey)
            let (passwordSeed, encryptionKey, signingKeyPair) = try createTeamSessionKeys(seed: sharedSeed)
            let pairingKeyPair = try Crypto.shared.createSigningKeyPair(seed: Crypto.shared.convertFromBase64(from: pairingQueueSeed)) // Used for pairing
            let session = TeamSession(id: browserPubKey.hash, signingPubKey: signingKeyPair.pubKey, title: "\(role) @ \(team)", version: 2, isAdmin: false)
            return firstly {
                try session.acknowledgeSessionStart(pairingKeyPair: pairingKeyPair, browserPubKey: browserPubKeyData, sharedKeyPubkey: keyPairForSharedKey.pubKey.base64)
            }.map { _ in
                do {
                    try session.save(key: encryptionKey, signingKeyPair: signingKeyPair, passwordSeed: passwordSeed)
                    TeamSession.count += 1
                    NotificationCenter.default.postMain(name: .subscriptionUpdated, object: nil, userInfo: ["status": Properties.hasValidSubscription])
                    return session
                } catch is KeychainError {
                    throw SessionError.exists
                } catch is CryptoError {
                    throw SessionError.invalid
                }
            }
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

    static func sync(pushed: Bool, logo: Bool, backup: Bool, pubKeys: [String]? = nil) -> Promise<Void> {
        return firstly {
            when(fulfilled: try TeamSession.all().compactMap { session -> Promise<Void>? in
                if let pubKeys = pubKeys {
                    guard pubKeys.contains(session.signingPubKey) else {
                         return nil
                    }
                }
                var promises = [updateTeamSession(session: session)]
                if logo {
                    promises.append(session.updateLogo())
                }
                if backup {
                    promises.append(session.backup())
                }
                return when(fulfilled: promises)
           })
        }
    }

    static func updateTeamSession(session: TeamSession, pushed: Bool = false) -> Promise<Void> {
        do {
            var session = session
            if !session.created && pushed {
                session.created = true
                try session.update()
                let _ = session.backup()
            }
            return firstly {
                API.shared.signedRequest(method: .get, message: nil, path: "teams/users/\(session.signingPubKey)", privKey: try session.signingPrivKey(), body: nil)
            }.map { result in
                guard let accounts = result["accounts"] as? [String: String] else {
                    throw CodingError.missingData
                }
                guard let isAdmin = result["admin"] as? Bool else {
                    throw CodingError.missingData
                }
                var changed = false
                if session.isAdmin != isAdmin {
                    session.isAdmin = isAdmin
                    changed = true
                    try session.update()
                }
                let updatedAccounts = try session.updateSharedAccounts(accounts: accounts)
                if changed || updatedAccounts > 0 {
                    NotificationCenter.default.postMain(name: .sharedAccountsChanged, object: nil)
                    NotificationCenter.default.postMain(name: .sessionUpdated, object: nil, userInfo: ["session": session, "count": accounts.count])
                }
            }.recover { error in
                if case APIError.statusCode(404) = error {
                    guard session.created else {
                        return
                    }
                    SharedAccount.deleteAll(for: session.signingPubKey)
                    try? session.delete()
                    NotificationCenter.default.postMain(name: .sessionEnded, object: nil, userInfo: [NotificationContentKey.sessionId: session.id])
                    NotificationCenter.default.postMain(name: .sharedAccountsChanged, object: nil)
                } else {
                    throw error
                }
            }.asVoid()
        } catch {
            return Promise(error: error)
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
        let pairingResponse = KeynTeamPairingResponse(sessionID: id, pubKey: sharedKeyPubkey, browserPubKey: browserPubKey.base64, userID: Properties.userId!, environment: Properties.environment.rawValue, type: .pair, version: version, userPubKey: try BackupManager.publicKey(), arn: endpoint)
        let jsonPairingResponse = try JSONEncoder().encode(pairingResponse)
        let ciphertext = try Crypto.shared.encrypt(jsonPairingResponse, pubKey: browserPubKey)
        let signedCiphertext = try Crypto.shared.sign(message: ciphertext, privKey: pairingKeyPair.privKey)
        let message = [
            "data": signedCiphertext.base64
        ]
        let jsonData = try JSONSerialization.data(withJSONObject: message, options: [])
        return API.shared.signedRequest(method: .put, message: nil, path: "sessions/\(pairingKeyPair.pubKey.base64)/pairing", privKey: pairingKeyPair.privKey, body: jsonData).asVoid().log("Error sending pairing response.")
    }

    func delete(notify: Bool) -> Promise<Void> {
        return firstly {
            API.shared.signedRequest(method: .delete, message: nil, path: "teams/users/\(signingPubKey)", privKey: try signingPrivKey(), body: nil)
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

    func save(key: Data, signingKeyPair: KeyPair, passwordSeed: Data) throws {
        let sessionData = try PropertyListEncoder().encode(self)
        try Keychain.shared.save(id: SessionIdentifier.sharedKey.identifier(for: id), service: TeamSession.encryptionService, secretData: key, objectData: sessionData)
        try Keychain.shared.save(id: SessionIdentifier.signingKeyPair.identifier(for: id), service: TeamSession.signingService, secretData: signingKeyPair.privKey)
        try Keychain.shared.save(id: SessionIdentifier.passwordSeed.identifier(for: id), service: TeamSession.signingService, secretData: passwordSeed)
    }

    func passwordSeed() throws -> Data {
        guard let seed = try Keychain.shared.get(id: SessionIdentifier.passwordSeed.identifier(for: id), service: TeamSession.signingService) else {
            throw KeychainError.notFound
        }
        return seed
    }

    func updateLogo() -> Promise<Void> {
        let filemgr = FileManager.default
//            var headers: [String:String]? = nil
        guard let path = logoPath else {
            return Promise(error: TeamSessionError.logoPathNotFound)
        }
//            if filemgr.fileExists(atPath: path), let creationDate = (try? filemgr.attributesOfItem(atPath: path) as NSDictionary)?.fileCreationDate() {
//                headers = ["modified-since": "\(creationDate.timeIntervalSince1970)"]
//                let rfcDateFormat = DateFormatter()
//                rfcDateFormat.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
//                headers["modified-since"] = rfcDateFormat.string(from: creationDate)
//            }
        return firstly {
            API.shared.signedRequest(method: .get, message: nil, path: "teams/users/\(signingPubKey)/logo", privKey: try signingPrivKey(), body: nil)
        }.map { result in
            guard let logo = result["logo"] as? String else {
                return
            }
            guard let data = Data(base64Encoded: logo, options: .ignoreUnknownCharacters), let _ = UIImage(data: data) else {
                throw CodingError.unexpectedData
            }
            if filemgr.fileExists(atPath: path) {
                try filemgr.removeItem(atPath: path)
            }
            filemgr.createFile(atPath: path, contents: data, attributes: nil)
        }.recover { error  in
            if case APIError.statusCode(404) = error {
                return
            } else {
                Logger.shared.error("Error retrieving logo", error: error)
            }
        }
    }

    // MARK: - Admin functions

    func getTeamSeed() -> Promise<Data> {
        return firstly {
            API.shared.signedRequest(method: .get, message: nil, path: "teams/users/\(signingPubKey)/admin", privKey: try signingPrivKey(), body: nil)
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
    }
}
