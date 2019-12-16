/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit
import UserNotifications
import LocalAuthentication

enum SessionError: KeynError {
    case exists
    case doesntExist
    case invalid
    case noEndpoint
    case signing
    case unknownType
    case destroyed
}

enum SessionIdentifier: String, Codable {
    case sharedKey = "shared"
    case signingKeyPair = "signing"
    case passwordSeed = "passwordSeed"

    func identifier(for id: String) -> String {
        return "\(id)-\(self.rawValue)"
    }
}

enum MessageType: String {
    case pairing, volatile, persistent, push
}

protocol Session: Codable {

    var creationDate: Date { get }
    var id: String { get }
    var signingPubKey: String { get }
    var title: String { get }
    var logo: UIImage? { get }
    var version: Int { get }

    func delete(notify: Bool) throws
    func acknowledgeSessionStart(pairingKeyPair: KeyPair, browserPubKey: Data, sharedKeyPubkey: String, completion: @escaping (Result<Void, Error>) -> Void) throws

    static var encryptionService: KeychainService { get }
    static var signingService: KeychainService { get }
    static var sessionCountFlag: String { get }

    static func initiate(pairingQueueSeed: String, browserPubKey: String, browser: String, os: String, version: Int, completionHandler: @escaping (Result<Session, Error>) -> Void)
}


// Shared functions for BrowserSession and TeamSession
extension Session {

    static var count: Int {
        get { return UserDefaults.standard.integer(forKey: Self.sessionCountFlag) }
        set { UserDefaults.standard.set(newValue, forKey: Self.sessionCountFlag) }
    }

    func signingPrivKey() throws -> Data {
        return try Keychain.shared.get(id: SessionIdentifier.signingKeyPair.identifier(for: id), service: Self.signingService)
    }

    func sharedKey() throws -> Data {
        return try Keychain.shared.get(id: SessionIdentifier.sharedKey.identifier(for: id), service: Self.encryptionService)
    }

    func decryptMessage<T: Decodable>(message: String) throws -> T {
        let ciphertext = try Crypto.shared.convertFromBase64(from: message)
        let (data, _) = try Crypto.shared.decrypt(ciphertext, key: sharedKey(), version: version)
        return try JSONDecoder().decode(T.self, from: data)
    }

    func deleteQueuesAtAWS() {
        do {
            let message = [
                "pubkey": signingPubKey
            ]
            API.shared.signedRequest(endpoint: .message, method: .delete, message: message, pubKey: nil, privKey: try signingPrivKey(), body: nil) { result in
                if case let .failure(error) = result {
                    Logger.shared.error("Cannot delete endpoint at AWS.", error: error)
                }
            }
        } catch {
            Logger.shared.error("Cannot delete endpoint at AWS.", error: error)
        }
    }

    // MARK: Static functions


    static func all() throws -> [Self] {
        var sessions = [Self]()
        guard let dataArray = try Keychain.shared.all(service: Self.encryptionService) else {
            return sessions
        }

        let decoder = PropertyListDecoder()

        for dict in dataArray {
            guard let sessionData = dict[kSecAttrGeneric as String] as? Data else {
                throw CodingError.unexpectedData
            }
            do {
                let session = try decoder.decode(Self.self, from: sessionData)
                sessions.append(session)
            } catch {
                Logger.shared.error("Can not decode session", error: error)
                guard let sessionId = dict[kSecAttrAccount as String] as? String, let _ = try? Keychain.shared.delete(id: sessionId, service: Self.encryptionService) else {
                    purgeSessionDataFromKeychain()
                    return []
                }
            }
        }
        Self.count = sessions.count
        return sessions
    }

    static func purgeSessionDataFromKeychain() {
        Keychain.shared.deleteAll(service: encryptionService)
        Keychain.shared.deleteAll(service: signingService)
        Self.count = 0
    }

    static func exists(id: String) throws -> Bool {
        return Keychain.shared.has(id: SessionIdentifier.sharedKey.identifier(for: id), service: encryptionService)
    }

    static func get(id: String) throws -> Self? {
        guard let sessionDict = try Keychain.shared.attributes(id: SessionIdentifier.sharedKey.identifier(for: id), service: encryptionService) else {
            return nil
        }
        guard let sessionData = sessionDict[kSecAttrGeneric as String] as? Data else {
            throw CodingError.unexpectedData
        }
        let decoder = PropertyListDecoder()
        return try decoder.decode(Self.self, from: sessionData)
    }

    static func deleteAll() {
        do {
            for session in try all() {
                try session.delete(notify: true)
            }
        } catch {
            Logger.shared.warning("Error deleting sessions.", error: error)
        }

        // To be sure
        purgeSessionDataFromKeychain()
    }

}
