/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit
import UserNotifications
import LocalAuthentication

class TeamSession: Session {

    var backgroundTask: Int = UIBackgroundTaskIdentifier.invalid.rawValue
    let role: String
    let creationDate: Date
    let id: String
    let company: String
    let signingPubKey: String
    var version: Int
    var title: String {
        return "\(role) at \(company)" // TODO: Localize
    }
    var logo: UIImage? {
        return UIImage(named: "logo_purple") // TODO: get logo from somewhere? Team db?
    }

    static let CRYPTO_CONTEXT = "keynteam"
    static var signingService: KeychainService = .signingTeamSessionKey
    static var encryptionService: KeychainService = .sharedTeamSessionKey
    static var sessionCountFlag: String = "teamSessionCount"

    static func initiate(pairingQueueSeed: String, browserPubKey: String, browser: String, os: String, version: Int, completionHandler: @escaping (Result<Session, Error>) -> Void) {
        do {
            let keyPairForSharedKey = try Crypto.shared.createSessionKeyPair()
            let browserPubKeyData = try Crypto.shared.convertFromBase64(from: browserPubKey)

            let sharedSeed = try Crypto.shared.generateSharedKey(pubKey: browserPubKeyData, privKey: keyPairForSharedKey.privKey)
            let passwordSeed =  try Crypto.shared.deriveKey(keyData: sharedSeed, context: CRYPTO_CONTEXT, index: 0) // Used to generate passwords
            let encryptionKey = try Crypto.shared.deriveKey(keyData: sharedSeed, context: CRYPTO_CONTEXT, index: 1) // Used to encrypt messages for this session
            let signingKeyPair = try Crypto.shared.createSigningKeyPair(seed: Crypto.shared.deriveKey(keyData: sharedSeed, context: CRYPTO_CONTEXT, index: 2)) // Used to sign messages for the server

            let pairingKeyPair = try Crypto.shared.createSigningKeyPair(seed: Crypto.shared.convertFromBase64(from: pairingQueueSeed)) // Used for pairing

            let session = TeamSession(id: browserPubKey.hash, signingPubKey: signingKeyPair.pubKey, role: browser, company: os, version: 2)
            try session.acknowledgeSessionStart(pairingKeyPair: pairingKeyPair, browserPubKey: browserPubKeyData, sharedKeyPubkey: keyPairForSharedKey.pubKey.base64)  { result in
                do {
                    let _ = try result.get()
                    try session.save(key: encryptionKey, signingKeyPair: signingKeyPair, passwordSeed: passwordSeed)
                    TeamSession.count += 1
                    NotificationCenter.default.post(name: .subscriptionUpdated, object: nil, userInfo: ["status": Properties.hasValidSubscription])
                    completionHandler(.success(session))
                } catch is KeychainError {
                    completionHandler(.failure(SessionError.exists))
                } catch is CryptoError {
                    completionHandler(.failure(SessionError.invalid))
                } catch {
                    completionHandler(.failure(error))
                }
            }
        } catch {
            Logger.shared.error("Error initiating session", error: error)
            completionHandler(.failure(error))
        }
    }

    init(id: String, signingPubKey: Data, role: String, company: String, version: Int) {
        self.creationDate = Date()
        self.id = id
        self.signingPubKey = signingPubKey.base64
        self.role = role
        self.company = company
        self.version = version
    }

    func updateSharedAccounts(completion: @escaping (Result<Void, Error>) -> Void) {
        do {
            API.shared.signedRequest(method: .get, message: nil, path: "teams/users/\(signingPubKey)", privKey: try signingPrivKey(), body: nil) { result in
                do {
                    var changed = false
                    let dict = try result.get()
                    let key = try self.passwordSeed()
                    #warning("TODO: If an account already exists because of an earlier session, now throws keyn.KeychainError.unhandledError(-25299). Handle better")
                    var currentAccounts = try TeamAccount.all(context: nil, label: self.id)
                    for (id, data) in dict {
                        currentAccounts.removeValue(forKey: id)
                        if let base64Data = data as? String {
                            let ciphertext = try Crypto.shared.convertFromBase64(from: base64Data)
                            let (accountData, _)  = try Crypto.shared.decrypt(ciphertext, key: self.sharedKey(), version: self.version)
                            if var account = try TeamAccount.get(accountID: id, context: nil) {
                                changed = try account.update(accountData: accountData, key: key)
                            } else { // New account added
                                try TeamAccount.create(accountData: accountData, id: id, key: key, context: nil, sessionPubKey: self.signingPubKey)
                                changed = true
                            }
                        }
                    }
                    for account in currentAccounts.values {
                        #warning("Check how to safely delete here in the background")
                        try account.delete()
                        changed = true
                    }
                    if changed {
                        NotificationCenter.default.post(name: .sharedAccountsChanged, object: nil)
                    }
                    completion(.success(()))
                } catch {
                    Logger.shared.error("Error retrieving accounts", error: error)
                    completion(.failure(error))
                }
            }
        } catch {
            Logger.shared.error("Error to get key to fetch accounts", error: error)
            completion(.failure(error))
        }
    }

    func acknowledgeSessionStart(pairingKeyPair: KeyPair, browserPubKey: Data, sharedKeyPubkey: String, completion: @escaping (Result<Void, Error>) -> Void) throws {
        guard let endpoint = Properties.endpoint else {
            throw SessionError.noEndpoint
        }
        let pairingResponse = KeynTeamPairingResponse(sessionID: id, pubKey: sharedKeyPubkey, browserPubKey: browserPubKey.base64, userID: Properties.userId!, environment: Properties.environment.rawValue, type: .pair, version: version, arn: endpoint)
        let jsonPairingResponse = try JSONEncoder().encode(pairingResponse)
        let ciphertext = try Crypto.shared.encrypt(jsonPairingResponse, pubKey: browserPubKey)
        let signedCiphertext = try Crypto.shared.sign(message: ciphertext, privKey: pairingKeyPair.privKey)
        let message = [
            "data": signedCiphertext.base64
        ]
        let jsonData = try JSONSerialization.data(withJSONObject: message, options: [])
        API.shared.signedRequest(method: .put, message: nil, path: "sessions/\(pairingKeyPair.pubKey.base64)/pairing", privKey: pairingKeyPair.privKey, body: jsonData) { result in
            if case let .failure(error) = result {
                Logger.shared.error("Error sending pairing response.", error: error)
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }

    func delete(notify: Bool, completion: @escaping (Result<Void, Error>) -> Void) {
        do {
            TeamAccount.deleteAll(for: signingPubKey)
            API.shared.signedRequest(method: .delete, message: nil, path: "teams/users/\(signingPubKey)", privKey: try signingPrivKey(), body: nil) { result in
                do {
                    let _ = try result.get()
                    try Keychain.shared.delete(id: SessionIdentifier.sharedKey.identifier(for: self.id), service: .sharedTeamSessionKey)
                    try Keychain.shared.delete(id: SessionIdentifier.signingKeyPair.identifier(for: self.id), service: .signingTeamSessionKey)
                    TeamSession.count -= 1
                    NotificationCenter.default.post(name: .subscriptionUpdated, object: nil, userInfo: ["status": Properties.hasValidSubscription])
                    completion(.success(()))
                } catch {
                    Logger.shared.error("Error deleting arn for team session", error: error)
                    completion(.failure(error))
                }
            }
        } catch {
            completion(.failure(error))
        }
    }

    func save(key: Data, signingKeyPair: KeyPair, passwordSeed: Data) throws {
        let sessionData = try PropertyListEncoder().encode(self)
        try Keychain.shared.save(id: SessionIdentifier.sharedKey.identifier(for: id), service: TeamSession.encryptionService, secretData: key, objectData: sessionData)
        try Keychain.shared.save(id: SessionIdentifier.signingKeyPair.identifier(for: id), service: TeamSession.signingService, secretData: signingKeyPair.privKey)
        try Keychain.shared.save(id: SessionIdentifier.passwordSeed.identifier(for: id), service: TeamSession.signingService, secretData: passwordSeed)
    }

    func passwordSeed() throws -> Data {
        return try Keychain.shared.get(id: SessionIdentifier.passwordSeed.identifier(for: id), service: TeamSession.signingService)
    }

    func decryptAdminSeed(seed: String) throws -> Data {
        let ciphertext = try Crypto.shared.convertFromBase64(from: seed)
        let (data, _) = try Crypto.shared.decrypt(ciphertext, key: self.sharedKey(), version: self.version)
        return data
    }

}
