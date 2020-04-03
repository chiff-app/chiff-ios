/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import Foundation
import LocalAuthentication
import PromiseKit

enum SeedError: KeynError {
    case mnemonicConversion
    case checksumFailed
    case exists
    case notFound
}

struct Seed {

    static let CRYPTO_CONTEXT = "keynseed"
    static var hasKeys: Bool {
        return Keychain.shared.has(id: KeyIdentifier.master.identifier(for: .seed), service: .seed) &&
        Keychain.shared.has(id: KeyIdentifier.backup.identifier(for: .seed), service: .seed) &&
        Keychain.shared.has(id: KeyIdentifier.password.identifier(for: .seed), service: .seed)
    }
    private static let paperBackupCompletedFlag = "paperBackupCompleted"
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

    static func create(context: LAContext?) -> Promise<Void> {
        guard !hasKeys && !BackupManager.hasKeys else {
            return Promise(error: SeedError.exists)
        }
        do {
            let seed = try Crypto.shared.generateSeed()
            let passwordSeed = try Crypto.shared.deriveKeyFromSeed(seed: seed, keyType: .passwordSeed, context: CRYPTO_CONTEXT)
            let webAuthnSeed = try Crypto.shared.deriveKeyFromSeed(seed: seed, keyType: .webAuthnSeed, context: CRYPTO_CONTEXT)
            let backupSeed = try Crypto.shared.deriveKeyFromSeed(seed: seed, keyType: .backupSeed, context: CRYPTO_CONTEXT)

            return firstly {
                BackupManager.initialize(seed: backupSeed, context: context)
            }.map { result in
                try Keychain.shared.save(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, secretData: seed)
                try Keychain.shared.save(id: KeyIdentifier.password.identifier(for: .seed), service: .seed, secretData: passwordSeed)
                try Keychain.shared.save(id: KeyIdentifier.backup.identifier(for: .seed), service: .seed, secretData: backupSeed)
                try Keychain.shared.save(id: KeyIdentifier.webauthn.identifier(for: .seed), service: .seed, secretData: webAuthnSeed)
            }.recover { error in
                NotificationManager.shared.deleteKeys()
                BackupManager.deleteKeys()
                delete()
                throw error
            }
        } catch {
            delete()
            return Promise(error: error)
        }
    }

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
    
    static func recover(context: LAContext, mnemonic: [String]) -> Promise<(Int,Int,Int,Int)> {
        guard !hasKeys && !BackupManager.hasKeys else {
            return Promise(error: SeedError.exists)
        }
        do {
            let (checksum, seed) = try generateSeedFromMnemonic(mnemonic: mnemonic)
            let checksumSize = seed.count / 4
            guard checksum == String(seed.sha256.first!, radix: 2).pad(toSize: 8).prefix(checksumSize) || checksum == oldChecksum(seed: seed) else {
                throw SeedError.checksumFailed
            }

            let passwordSeed = try Crypto.shared.deriveKeyFromSeed(seed: seed, keyType: .passwordSeed, context: CRYPTO_CONTEXT)
            let backupSeed = try Crypto.shared.deriveKeyFromSeed(seed: seed, keyType: .backupSeed, context: CRYPTO_CONTEXT)

            try Keychain.shared.save(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, secretData: seed)
            try Keychain.shared.save(id: KeyIdentifier.password.identifier(for: .seed), service: .seed, secretData: passwordSeed)
            try Keychain.shared.save(id: KeyIdentifier.backup.identifier(for: .seed), service: .seed, secretData: backupSeed)
            paperBackupCompleted = true

            return try BackupManager.getBackupData(seed: backupSeed, context: context)
        } catch {
            NotificationManager.shared.deleteKeys()
            BackupManager.deleteKeys()
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
            let webAuthnSeed = try Crypto.shared.deriveKeyFromSeed(seed: masterSeed, keyType: .webAuthnSeed, context: CRYPTO_CONTEXT)
            try Keychain.shared.save(id: KeyIdentifier.webauthn.identifier(for: .seed), service: .seed, secretData: webAuthnSeed)
            return webAuthnSeed
        }
        return seed
    }

    static func delete() {
        UserDefaults.standard.removeObject(forKey: paperBackupCompletedFlag)
        Keychain.shared.deleteAll(service: .seed)
    }

    // MARK: - Private

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
