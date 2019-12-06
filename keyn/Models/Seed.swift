/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import Foundation
import LocalAuthentication

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
                NotificationCenter.default.post(name: .backupCompleted, object: self)
            }
        }
    }

    enum KeyType: UInt64 {
        case passwordSeed = 0
        case backupSeed = 1
    }

    static func create(context: LAContext?, completionHandler: @escaping (Result<Void, Error>) -> Void) {
        guard !hasKeys && !BackupManager.shared.hasKeys else {
            completionHandler(.failure(SeedError.exists))
            return
        }
        do {

            let seed = try Crypto.shared.generateSeed()
            let passwordSeed = try Crypto.shared.deriveKeyFromSeed(seed: seed, keyType: .passwordSeed, context: CRYPTO_CONTEXT)
            let backupSeed = try Crypto.shared.deriveKeyFromSeed(seed: seed, keyType: .backupSeed, context: CRYPTO_CONTEXT)

            BackupManager.shared.initialize(seed: backupSeed, context: context) { result in
                do {
                    switch result {
                    case .success(_):
                        try Keychain.shared.save(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, secretData: seed)
                        try Keychain.shared.save(id: KeyIdentifier.password.identifier(for: .seed), service: .seed, secretData: passwordSeed)
                        try Keychain.shared.save(id: KeyIdentifier.backup.identifier(for: .seed), service: .seed, secretData: backupSeed)
                        completionHandler(.success(()))
                    case .failure(let error): throw error
                    }
                } catch {
                    NotificationManager.shared.deleteKeys()
                    BackupManager.shared.deleteKeys()
                    try? delete()
                    completionHandler(.failure(error))
                }
            }
        } catch {
            try? delete()
            completionHandler(.failure(error))
        }
    }

    static func mnemonic(completionHandler: @escaping (Result<[String], Error>) -> Void) {
        Keychain.shared.get(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, reason: "backup.retrieve".localized, authenticationType: .ifNeeded) { (result) in
            do {
                switch result {
                case .success(let seed):
                    let checksumSize = seed.count / 4
                    let bitstring = seed.bitstring + String(seed.sha256.first!, radix: 2).pad(toSize: 8).prefix(checksumSize)
                    let wordlist = try self.localizedWordlist()
                    let mnemonic = bitstring.components(withLength: 11).map({ wordlist[Int($0, radix: 2)!] })
                    completionHandler(.success(mnemonic))
                case .failure(let error): throw error
                }
            } catch {
                completionHandler(.failure(error))
            }
        }
    }
    
    static func validate(mnemonic: [String]) -> Bool {
        guard let (checksum, seed) = try? generateSeedFromMnemonic(mnemonic: mnemonic) else {
            return false
        }

        let checksumSize = seed.count / 4
        return checksum == String(seed.sha256.first!, radix: 2).pad(toSize: 8).prefix(checksumSize) || checksum == oldChecksum(seed: seed)
    }
    
    static func recover(context: LAContext, mnemonic: [String], completionHandler: @escaping (Result<(Int,Int), Error>) -> Void) {
        guard !hasKeys && !BackupManager.shared.hasKeys else {
            completionHandler(.failure(SeedError.exists))
            return
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

            try BackupManager.shared.getBackupData(seed: backupSeed, context: context, completionHandler: completionHandler)
        } catch {
            NotificationManager.shared.deleteKeys()
            BackupManager.shared.deleteKeys()
            try? delete()
            completionHandler(.failure(error))
        }
    }

    static func getPasswordSeed(context: LAContext?) throws -> Data {
        return try Keychain.shared.get(id: KeyIdentifier.password.identifier(for: .seed), service: .seed, context: context)
    }

    static func getBackupSeed(context: LAContext?) throws -> Data {
        return try Keychain.shared.get(id: KeyIdentifier.backup.identifier(for: .seed), service: .seed, context: context)
    }

    static func delete() throws {
        UserDefaults.standard.removeObject(forKey: paperBackupCompletedFlag)
        try Keychain.shared.delete(id: KeyIdentifier.master.identifier(for: .seed), service: .seed)
        try Keychain.shared.delete(id: KeyIdentifier.backup.identifier(for: .seed), service: .seed)
        try Keychain.shared.delete(id: KeyIdentifier.password.identifier(for: .seed), service: .seed)
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
