/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import Foundation
import LocalAuthentication
import PromiseKit

enum SeedError: Error {
    case mnemonicConversion
    case checksumFailed
    case exists
    case notFound
}

struct Seed {

    private static let SEED_CRYPTO_CONTEXT = "keynseed"
    private static let paperBackupCompletedFlag = "paperBackupCompleted"
    private static let BACKUP_CRYPTO_CONTEXT = "keynback"

    static var hasKeys: Bool {
        return Keychain.shared.has(id: KeyIdentifier.master.identifier(for: .seed), service: .seed) &&
        Keychain.shared.has(id: KeyIdentifier.backup.identifier(for: .seed), service: .seed) &&
        Keychain.shared.has(id: KeyIdentifier.password.identifier(for: .seed), service: .seed) &&
        Keychain.shared.has(id: KeyIdentifier.pub.identifier(for: .backup), service: .backup) &&
        Keychain.shared.has(id: KeyIdentifier.priv.identifier(for: .backup), service: .backup) &&
        Keychain.shared.has(id: KeyIdentifier.encryption.identifier(for: .backup), service: .backup)
    }

    static var paperBackupCompleted: Bool {
        get {
            return UserDefaults.standard.bool(forKey: paperBackupCompletedFlag)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: paperBackupCompletedFlag)
            if newValue {
                NotificationCenter.default.postMain(name: .backupCompleted, object: self)
            }
        }
    }

    // MARK: - Create and restore

    static func create(context: LAContext?) -> Promise<Void> {
        guard !hasKeys else {
            return Promise(error: SeedError.exists)
        }
        Properties.migrated = true
        do {
            Keychain.shared.deleteAll(service: .backup)
            NotificationManager.shared.deleteKeys()
            let seed = try Crypto.shared.generateSeed()
            let (keyPair, userId) = try createKeys(seed: seed)
            return firstly {
                API.shared.signedRequest(method: .post, message: ["userId": userId], path: "users/\(keyPair.pubKey.base64)", privKey: keyPair.privKey, body: nil, parameters: nil)
            }.asVoid().recover { error in
                NotificationManager.shared.deleteKeys()
                delete()
                throw error
            }
        } catch {
            NotificationManager.shared.deleteKeys()
            delete()
            return Promise(error: error)
        }
    }

    static func recreateBackup() -> Promise<Void> {
        return firstly {
            API.shared.signedRequest(method: .post, message: ["userId": Properties.userId as Any], path: "users/\(try publicKey())", privKey: try privateKey(), body: nil, parameters: nil)
        }.asVoid().then { () -> Promise<Void> in
            var promises: [Promise<Void>] = []
            for account in try UserAccount.all(context: nil).values {
                promises.append(try account.backup())
            }
            for session in try TeamSession.all(context: nil).values {
                promises.append(session.backup())
            }
            return when(fulfilled: promises)
        }.then { _ in
            when(fulfilled: UserAccount.sync(context: nil), TeamSession.sync(context: nil))
        }
    }

    static func recover(context: LAContext, mnemonic: [String]) -> Promise<(Int,Int,Int,Int)> {
        guard !hasKeys else {
            return Promise(error: SeedError.exists)
        }
        do {
            let (checksum, seed) = try generateSeedFromMnemonic(mnemonic: mnemonic)
            let checksumSize = seed.count / 4
            guard checksum == String(seed.sha256.first!, radix: 2).pad(toSize: 8).prefix(checksumSize) || checksum == oldChecksum(seed: seed) else {
                throw SeedError.checksumFailed
            }
            _ = try createKeys(seed: seed)
            paperBackupCompleted = true
            return firstly {
                setMigrated()
            }.then {
                when(fulfilled:
                    UserAccount.restore(context: context),
                    TeamSession.restore(context: context))
            }.then { result in
                TeamSession.updateAllTeamSessions(pushed: false, filterLogos: nil).map { _ in
                    return result
                }
            }.map { result in
                let ((accountsSucceeded, accountsFailed), (sessionsSucceeded, sessionsFailed)) = result
                Properties.accountCount = accountsSucceeded
                return (accountsSucceeded + accountsFailed, accountsFailed, sessionsSucceeded + sessionsFailed, sessionsFailed)
            }.recover { error -> Promise<(Int,Int,Int,Int)> in
                NotificationManager.shared.deleteKeys()
                delete()
                throw error
            }
        } catch {
            NotificationManager.shared.deleteKeys()
            delete()
            return Promise(error: error)
        }
    }

    static func getPasswordSeed(context: LAContext?) throws -> Data {
        guard let seed = try Keychain.shared.get(id: KeyIdentifier.password.identifier(for: .seed), service: .seed, context: context) else {
            throw SeedError.notFound
        }
        return seed
    }

    static func getBackupSeed(context: LAContext?) throws -> Data {
        guard let seed = try Keychain.shared.get(id: KeyIdentifier.backup.identifier(for: .seed), service: .seed, context: context) else {
            throw SeedError.notFound
        }
        return seed
    }

    static func getWebAuthnSeed(context: LAContext?) throws -> Data {
        guard let seed = try Keychain.shared.get(id: KeyIdentifier.webauthn.identifier(for: .seed), service: .seed, context: context) else {
            guard let masterSeed = try Keychain.shared.get(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, context: context) else {
                throw SeedError.notFound
            }
            let webAuthnSeed = try Crypto.shared.deriveKeyFromSeed(seed: masterSeed, keyType: .webAuthnSeed, context: SEED_CRYPTO_CONTEXT)
            try Keychain.shared.save(id: KeyIdentifier.webauthn.identifier(for: .seed), service: .seed, secretData: webAuthnSeed)
            return webAuthnSeed
        }
        return seed
    }

    static func delete() {
        UserDefaults.standard.removeObject(forKey: paperBackupCompletedFlag)
        Keychain.shared.deleteAll(service: .seed)
        Keychain.shared.deleteAll(service: .backup)
    }

    static func deleteBackupData() -> Promise<Void> {
        return firstly {
            API.shared.signedRequest(method: .delete, message: nil, path: "/users/\(try publicKey())", privKey: try privateKey(), body: nil, parameters: nil)
        }.asVoid().log("BackupManager cannot delete account.")
    }

    static func moveToProduction() -> Promise<Void> {
        do {
            guard Properties.environment == .beta && !Properties.migrated else {
                return .value(())
            }
            let message = [
                "sessions": try BrowserSession.all().map { [
                    "pk": $0.signingPubKey,
                    "message": try Crypto.shared.sign(message: JSONSerialization.data(withJSONObject: [
                            "timestamp": Date.now,
                            "data": try $0.encryptSessionData(organisationKey: try? TeamSession.all().first?.organisationKey, migrated: true)
                        ], options: []), privKey: try $0.signingPrivKey()).base64,
                    ]
                }
            ]
            return firstly {
                API.shared.signedRequest(method: .patch, message: message, path: "users/\(try publicKey())", privKey: try privateKey(), body: nil, parameters: nil)
            }.asVoid()
        } catch {
            return Promise(error: error)
        }
    }

    static func setMigrated() -> Promise<Void> {
        guard Properties.environment == .beta else {
            return .value(())
        }
        return firstly {
            API.shared.signedRequest(method: .get, message: nil, path: "users/\(try publicKey())/migrated", privKey: try privateKey(), body: nil, parameters: nil)
        }.map { result in
            guard let migrated = result["migrated"] as? Bool else {
                Logger.shared.warning("Error parsing migrated status")
                return
            }
            Properties.migrated = migrated
        }.asVoid().recover { error in
            guard case APIError.statusCode(404) = error else {
                Logger.shared.warning("Error getting migrated status")
                return
            }
            return
        }
    }

    static func publicKey() throws -> String {
        guard let pubKey = try Keychain.shared.get(id: KeyIdentifier.pub.identifier(for: .backup), service: .backup) else {
            throw KeychainError.notFound
        }
        let base64PubKey = try Crypto.shared.convertToBase64(from: pubKey)
        return base64PubKey
    }

    static func privateKey() throws -> Data {
        guard let privKey = try Keychain.shared.get(id: KeyIdentifier.priv.identifier(for: .backup), service: .backup) else {
            throw KeychainError.notFound
        }
        return privKey
    }

    // MARK: - Mnemonic

    static func mnemonic() -> Promise<[String]> {
        return firstly {
            Keychain.shared.get(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, reason: "backup.retrieve".localized, authenticationType: .ifNeeded)
        }.map { seed in
            guard let seed = seed else {
                throw SeedError.notFound
            }
            let checksumSize = seed.count / 4
            let bitstring = seed.bitstring + String(seed.sha256.first!, radix: 2).pad(toSize: 8).prefix(checksumSize)
            let wordlist = try self.localizedWordlist()
            return bitstring.components(withLength: 11).map({ wordlist[Int($0, radix: 2)!] })
        }
    }

    static func validate(mnemonic: [String]) -> Bool {
        guard let (checksum, seed) = try? generateSeedFromMnemonic(mnemonic: mnemonic) else {
            return false
        }

        let checksumSize = seed.count / 4
        return checksum == String(seed.sha256.first!, radix: 2).pad(toSize: 8).prefix(checksumSize) || checksum == oldChecksum(seed: seed)
    }


    // MARK: - Private methods

    private static func createKeys(seed: Data) throws -> (KeyPair, String) {
        let passwordSeed = try Crypto.shared.deriveKeyFromSeed(seed: seed, keyType: .passwordSeed, context: SEED_CRYPTO_CONTEXT)
        let webAuthnSeed = try Crypto.shared.deriveKeyFromSeed(seed: seed, keyType: .webAuthnSeed, context: SEED_CRYPTO_CONTEXT)
        let backupSeed = try Crypto.shared.deriveKeyFromSeed(seed: seed, keyType: .backupSeed, context: SEED_CRYPTO_CONTEXT)
        let encryptionKey = try Crypto.shared.deriveKey(keyData: backupSeed, context: BACKUP_CRYPTO_CONTEXT)
        let keyPair = try Crypto.shared.createSigningKeyPair(seed: backupSeed)
        let base64PubKey = try Crypto.shared.convertToBase64(from: keyPair.pubKey)
        let userId = "\(base64PubKey)_KEYN_USER_ID".sha256

        try Keychain.shared.save(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, secretData: seed)
        try Keychain.shared.save(id: KeyIdentifier.password.identifier(for: .seed), service: .seed, secretData: passwordSeed)
        try Keychain.shared.save(id: KeyIdentifier.backup.identifier(for: .seed), service: .seed, secretData: backupSeed)
        try Keychain.shared.save(id: KeyIdentifier.webauthn.identifier(for: .seed), service: .seed, secretData: webAuthnSeed)
        try Keychain.shared.save(id: KeyIdentifier.encryption.identifier(for: .backup), service: .backup, secretData: encryptionKey)
        try Keychain.shared.save(id: KeyIdentifier.pub.identifier(for: .backup), service: .backup, secretData: keyPair.pubKey)
        try Keychain.shared.save(id: KeyIdentifier.priv.identifier(for: .backup), service: .backup, secretData: keyPair.privKey)
        Properties.userId = userId
        return (keyPair, userId)
    }

    static func wordlists() throws -> [[String]] {
        let bundle = Bundle.main
        return try bundle.localizations.compactMap { (localization) in
            guard let path = bundle.path(forResource: "wordlist", ofType: "txt", inDirectory: nil, forLocalization: localization) else {
                return nil
            }
            let wordlistData = try String(contentsOfFile: path, encoding: .utf8)
            return wordlistData.components(separatedBy: .newlines)
        }
    }

    static func localizedWordlist() throws -> [String] {
        let wordlistData = try String(contentsOfFile: Bundle.main.path(forResource: "wordlist", ofType: "txt")!, encoding: .utf8)
        return wordlistData.components(separatedBy: .newlines)
    }
    
    static private func generateSeedFromMnemonic(mnemonic: [String]) throws -> (Substring, Data) {
        let wordlists = try self.wordlists()
        guard let wordlist = (wordlists.first { Set(mnemonic).isSubset(of: (Set($0))) }) else {
            throw SeedError.mnemonicConversion
        }

        let bitstring = try mnemonic.reduce("") { (result, word) throws -> String in
            guard let index: Int = wordlist.firstIndex(of: word) else {
                throw SeedError.mnemonicConversion
            }
            return result + String(index, radix: 2).pad(toSize: 11)
        }
        
        let checksum = bitstring.suffix(mnemonic.count / 3)
        let seedString = String(bitstring.prefix(bitstring.count - checksum.count))
        let seed = try seedString.components(withLength: 8).map { (byteString) throws -> UInt8 in
            guard let byte = UInt8(byteString, radix: 2) else {
                throw SeedError.mnemonicConversion
            }
            return byte
        }
        
        return (checksum, seed.data)
    }

    // MARK: - temporary

    static private func oldChecksum(seed: Data) -> String {
        return String(seed.hash.first!, radix: 2).prefix(seed.count / 4).pad(toSize: seed.count / 4)
    }
}
