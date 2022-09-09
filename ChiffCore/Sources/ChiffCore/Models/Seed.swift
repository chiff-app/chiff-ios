//
//  Seed.swift
//  ChiffCore
//
//  Copyright: see LICENSE.md
//

import Foundation
import LocalAuthentication
import PromiseKit

enum SeedError: Error {
    case mnemonicConversion
    case checksumFailed
    case exists
    case notFound
}

/// The seed from which passwords and keys are derived.
public struct Seed {

    private static let seedCryptoContext = "keynseed"
    private static let paperBackupCompletedFlag = "paperBackupCompleted"
    private static let backupCryptoContext = "keynback"

    /// Whether this seed has been initialized and subkeys saved to the Keychain.
    public static var hasKeys: Bool {
        return Keychain.shared.has(id: KeyIdentifier.master.identifier(for: .seed), service: .seed) &&
        Keychain.shared.has(id: KeyIdentifier.backup.identifier(for: .seed), service: .seed) &&
        Keychain.shared.has(id: KeyIdentifier.password.identifier(for: .passwordSeed), service: .passwordSeed) &&
        Keychain.shared.has(id: KeyIdentifier.pub.identifier(for: .backup), service: .backup) &&
        Keychain.shared.has(id: KeyIdentifier.priv.identifier(for: .backup), service: .backup) &&
        Keychain.shared.has(id: KeyIdentifier.encryption.identifier(for: .backup), service: .backup)
    }

    /// Whether the paper backup check has been completed.
    public static var paperBackupCompleted: Bool {
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

    /// Create a new seed.
    /// - Parameter context: Optionally, an authenticated `LAContext` object.
    public static func create(context: LAContext?) -> Promise<Void> {
        guard !hasKeys else {
            return Promise(error: SeedError.exists)
        }
        Properties.migrated = true
        do {
            delete(includeSeed: false)
            let seed = try Crypto.shared.generateSeed()
            let (keyPair, userId) = try createKeys(seed: seed)
            return firstly {
                API.shared.signedRequest(path: "users/\(keyPair.pubKey.base64)", method: .post, privKey: keyPair.privKey, message: ["userId": userId])
            }.asVoid().recover { error in
                delete(includeSeed: true)
                throw error
            }
        } catch {
            delete(includeSeed: true)
            return Promise(error: error)
        }
    }

    /// Recreate the backup remotely, after it has been deleted from another device.
    public static func recreateBackup() -> Promise<Void> {
        return firstly {
            API.shared.signedRequest(path: "users/\(try publicKey())", method: .post, privKey: try privateKey(), message: ["userId": Properties.userId as Any])
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

    /// Recover a seed from a mnemonic.
    /// - Parameters:
    ///   - context: An authenticated `LAContext` object.
    ///   - mnemonic: The 12 word mnemonic.
    /// - Returns: A tuple with information about how many accounts and how many team sessions were successfully recovered.
    public static func recover(context: LAContext, mnemonic: [String]) -> Promise<(RecoveryResult, RecoveryResult)> {
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
                    TeamSession.restore(context: context),
                    SSHIdentity.restore(context: context))
            }.then { (accountResult, sessionResult, sshResult) in
                TeamSession.updateAllTeamSessions().map { _ in
                    return (accountResult, sessionResult, sshResult)
                }
            }.map { (accountResult, sessionResult, sshResult) in
                Properties.accountCount = accountResult.succeeded
                let totalAccount = RecoveryResult(succeeded: accountResult.succeeded + sshResult.succeeded, failed: accountResult.failed + sshResult.failed)
                return (totalAccount, sessionResult)
            }.recover { error -> Promise<(RecoveryResult, RecoveryResult)> in
                delete(includeSeed: true)
                TeamSession.purgeSessionDataFromKeychain()
                UserAccount.deleteAll()
                SSHIdentity.deleteAll()
                throw error
            }
        } catch {
            delete(includeSeed: true)
            return Promise(error: error)
        }
    }

    /// Retrieve the password seed from the Keychain
    /// - Parameter context: Optionally, an authenticated `LAContext` object.
    /// - Throws: `SeedError` if the item is not found.
    /// - Returns: The seed data.
    static func getPasswordSeed(context: LAContext?) throws -> Data {
        guard let seed = try Keychain.shared.get(id: KeyIdentifier.password.identifier(for: .passwordSeed), service: .passwordSeed, context: context) else {
            throw SeedError.notFound
        }
        return seed
    }

    /// Retrieve the backup seed from the Keychain
    /// - Parameter context: Optionally, an authenticated `LAContext` object.
    /// - Throws: `SeedError` if the item is not found.
    /// - Returns: The seed data.
    static func getBackupSeed(context: LAContext?) throws -> Data {
        guard let seed = try Keychain.shared.get(id: KeyIdentifier.backup.identifier(for: .seed), service: .seed, context: context) else {
            throw SeedError.notFound
        }
        return seed
    }

    /// Retrieve the webauthn seed from the Keychain
    /// - Parameter context: Optionally, an authenticated `LAContext` object.
    /// - Throws: `SeedError` if the item is not found.
    /// - Returns: The seed data.
    static func getWebAuthnSeed(context: LAContext?) throws -> Data {
        guard let seed = try Keychain.shared.get(id: KeyIdentifier.webauthn.identifier(for: .seed), service: .seed, context: context) else {
            guard let masterSeed = try Keychain.shared.get(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, context: context) else {
                throw SeedError.notFound
            }
            let webAuthnSeed = try Crypto.shared.deriveKeyFromSeed(seed: masterSeed, keyType: .webAuthnSeed, context: seedCryptoContext)
            try Keychain.shared.save(id: KeyIdentifier.webauthn.identifier(for: .seed), service: .seed, secretData: webAuthnSeed)
            return webAuthnSeed
        }
        return seed
    }

    /// Retrieve the ssh seed from the Keychain
    /// - Parameter context: Optionally, an authenticated `LAContext` object.
    /// - Throws: `SeedError` if the item is not found.
    /// - Returns: The seed data.
    static func getSSHSeed(context: LAContext?) throws -> Data {
        guard let seed = try Keychain.shared.get(id: KeyIdentifier.ssh.identifier(for: .seed), service: .seed, context: context) else {
            guard let masterSeed = try Keychain.shared.get(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, context: context) else {
                throw SeedError.notFound
            }
            let sshSeed = try Crypto.shared.deriveKeyFromSeed(seed: masterSeed, keyType: .sshSeed, context: seedCryptoContext)
            try Keychain.shared.save(id: KeyIdentifier.ssh.identifier(for: .seed), service: .seed, secretData: sshSeed)
            return sshSeed
        }
        return seed
    }

    /// Delete all seeds from the Keychain.
    public static func delete(includeSeed: Bool) {
        if includeSeed {
            UserDefaults.standard.removeObject(forKey: paperBackupCompletedFlag)
            Keychain.shared.deleteAll(service: .seed)
        }
        Keychain.shared.deleteAll(service: .aws)
        Keychain.shared.deleteAll(service: .backup)
    }

    /// Delete the backup data from the server.
    public static func deleteBackupData() -> Promise<Void> {
        return firstly {
            API.shared.signedRequest(path: "/users/\(try publicKey())", method: .delete, privKey: try privateKey())
        }.asVoid().log("BackupManager cannot delete account.")
    }

    /// Get the base64-encoded public key of the signing keypair for this seed.
    public static func publicKey() throws -> String {
        guard let pubKey = try Keychain.shared.get(id: KeyIdentifier.pub.identifier(for: .backup), service: .backup) else {
            throw KeychainError.notFound
        }
        let base64PubKey = try Crypto.shared.convertToBase64(from: pubKey)
        return base64PubKey
    }

    /// Get the private key of the signing keypair for this seed.
    public static func privateKey() throws -> Data {
        guard let privKey = try Keychain.shared.get(id: KeyIdentifier.priv.identifier(for: .backup), service: .backup) else {
            throw KeychainError.notFound
        }
        return privKey
    }

    // MARK: - Mnemonic

    /// Convert the seed to a 12-word mnemonic.
    /// - Returns: A list of 12 words.
    public static func mnemonic() -> Promise<[String]> {
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

    /// Validate whether the checksum is correct for this mnemonic.
    /// - Parameter mnemonic: The 12-word mnemonic
    /// - Returns: True if the checksum is correct.
    public static func validate(mnemonic: [String]) -> Bool {
        guard let (checksum, seed) = try? generateSeedFromMnemonic(mnemonic: mnemonic) else {
            return false
        }

        let checksumSize = seed.count / 4
        return checksum == String(seed.sha256.first!, radix: 2).pad(toSize: 8).prefix(checksumSize) || checksum == oldChecksum(seed: seed)
    }

    // MARK: - Private methods

    private static func createKeys(seed: Data) throws -> (KeyPair, String) {
        let passwordSeed = try Crypto.shared.deriveKeyFromSeed(seed: seed, keyType: .passwordSeed, context: seedCryptoContext)
        let webAuthnSeed = try Crypto.shared.deriveKeyFromSeed(seed: seed, keyType: .webAuthnSeed, context: seedCryptoContext)
        let backupSeed = try Crypto.shared.deriveKeyFromSeed(seed: seed, keyType: .backupSeed, context: seedCryptoContext)
        let encryptionKey = try Crypto.shared.deriveKey(keyData: backupSeed, context: backupCryptoContext)
        let keyPair = try Crypto.shared.createSigningKeyPair(seed: backupSeed)
        let base64PubKey = try Crypto.shared.convertToBase64(from: keyPair.pubKey)
        let userId = "\(base64PubKey)_KEYN_USER_ID".sha256

        try Keychain.shared.save(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, secretData: seed)
        try Keychain.shared.save(id: KeyIdentifier.password.identifier(for: .passwordSeed), service: .passwordSeed, secretData: passwordSeed)
        try Keychain.shared.save(id: KeyIdentifier.backup.identifier(for: .seed), service: .seed, secretData: backupSeed)
        try Keychain.shared.save(id: KeyIdentifier.webauthn.identifier(for: .seed), service: .seed, secretData: webAuthnSeed)
        try Keychain.shared.save(id: KeyIdentifier.encryption.identifier(for: .backup), service: .backup, secretData: encryptionKey)
        try Keychain.shared.save(id: KeyIdentifier.pub.identifier(for: .backup), service: .backup, secretData: keyPair.pubKey)
        try Keychain.shared.save(id: KeyIdentifier.priv.identifier(for: .backup), service: .backup, secretData: keyPair.privKey)
        Properties.userId = userId
        return (keyPair, userId)
    }

    public static func wordlists() throws -> [[String]] {
        let bundle = Bundle.module
        return try bundle.localizations.compactMap { (localization) in
            guard let path = bundle.path(forResource: "wordlist", ofType: "txt", inDirectory: nil, forLocalization: localization) else {
                return nil
            }
            let wordlistData = try String(contentsOfFile: path, encoding: .utf8)
            return wordlistData.components(separatedBy: .newlines)
        }
    }

    static func localizedWordlist() throws -> [String] {
        let wordlistData = try String(contentsOfFile: Bundle.module.path(forResource: "wordlist", ofType: "txt")!, encoding: .utf8)
        return wordlistData.components(separatedBy: .newlines)
    }

    private static func generateSeedFromMnemonic(mnemonic: [String]) throws -> (Substring, Data) {
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

    private static func oldChecksum(seed: Data) -> String {
        return String(seed.hash!.first!, radix: 2).prefix(seed.count / 4).pad(toSize: seed.count / 4)
    }
}
