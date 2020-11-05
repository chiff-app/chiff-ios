//
//  Session.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import UIKit
import UserNotifications
import LocalAuthentication
import PromiseKit

enum SessionError: Error {
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
    case sharedSeed = "sharedSeed"
    case sharedKeyPrivKey = "sharedKeyPrivKey"

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
    var title: String { get set }
    var logo: UIImage? { get }
    var version: Int { get }

    func delete(notify: Bool) -> Promise<Void>
    mutating func update(makeBackup: Bool) throws

    static var encryptionService: KeychainService { get }
    static var signingService: KeychainService { get }
    static var sessionCountFlag: String { get }
}

// Shared functions for BrowserSession and TeamSession
extension Session {

    static var count: Int {
        get { return UserDefaults.standard.integer(forKey: Self.sessionCountFlag) }
        set { UserDefaults.standard.set(newValue, forKey: Self.sessionCountFlag) }
    }

    func signingPrivKey() throws -> Data {
        guard let key = try Keychain.shared.get(id: SessionIdentifier.signingKeyPair.identifier(for: id), service: Self.signingService) else {
            throw KeychainError.notFound
        }
        return key
    }

    func sharedKey() throws -> Data {
        guard let key = try Keychain.shared.get(id: SessionIdentifier.sharedKey.identifier(for: id), service: Self.encryptionService) else {
            throw KeychainError.notFound
        }
        return key
    }

    func decryptMessage<T: Decodable>(message: String) throws -> T {
        let ciphertext = try Crypto.shared.convertFromBase64(from: message)
        let (data, _) = try Crypto.shared.decrypt(ciphertext, key: sharedKey(), version: version)
        return try JSONDecoder().decode(T.self, from: data)
    }

    func deleteQueuesAtAWS() -> Promise<Void> {
        return firstly {
            API.shared.signedRequest(path: "sessions/\(signingPubKey)", method: .delete, privKey: try signingPrivKey()).asVoid()
        }.log("Cannot delete endpoint at AWS.")
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
                guard let sessionId = dict[kSecAttrAccount as String] as? String, (try? Keychain.shared.delete(id: sessionId, service: Self.encryptionService)) != nil else {
                    purgeSessionDataFromKeychain()
                    return []
                }
            }
        }
        Self.count = sessions.count
        return sessions
    }

    func acknowledgeSessionStart<T: PairingResponse>(pairingKeyPair: KeyPair, browserPubKey: Data, pairingResponse: T) -> Promise<Void> {
        do {
            let jsonPairingResponse = try JSONEncoder().encode(pairingResponse)
            let ciphertext = try Crypto.shared.encrypt(jsonPairingResponse, pubKey: browserPubKey)
            let signedCiphertext = try Crypto.shared.sign(message: ciphertext, privKey: pairingKeyPair.privKey)
            let message = [
                "data": signedCiphertext.base64
            ]
            let jsonData = try JSONSerialization.data(withJSONObject: message, options: [])
            return API.shared.signedRequest(path: "sessions/\(pairingKeyPair.pubKey.base64)/pairing",
                                            method: .put,
                                            privKey: pairingKeyPair.privKey,
                                            body: jsonData)
                .asVoid()
                .log("Error sending pairing response.")
        } catch {
            return Promise(error: error)
        }
    }

    static func purgeSessionDataFromKeychain() {
        Keychain.shared.deleteAll(service: encryptionService)
        Keychain.shared.deleteAll(service: signingService)
        Self.count = 0
    }

    static func exists(id: String) throws -> Bool {
        return Keychain.shared.has(id: SessionIdentifier.sharedKey.identifier(for: id), service: encryptionService)
    }

    static func get(id: String, context: LAContext?) throws -> Self? {
        guard let sessionDict = try Keychain.shared.attributes(id: SessionIdentifier.sharedKey.identifier(for: id), service: encryptionService, context: context) else {
            return nil
        }
        guard let sessionData = sessionDict[kSecAttrGeneric as String] as? Data else {
            throw CodingError.unexpectedData
        }
        let decoder = PropertyListDecoder()
        return try decoder.decode(Self.self, from: sessionData)
    }

    static func deleteAll() -> Promise<Void> {
        return firstly {
            when(resolved: try all().map { session in
                session.delete(notify: true).log("Error deleting sessions remotely.")
            }).asVoid()
        }
    }

}
