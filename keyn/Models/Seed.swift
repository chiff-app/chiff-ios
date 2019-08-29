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
            UserDefaults.standard.set(true, forKey: paperBackupCompletedFlag)
        }
    }

    private enum KeyIdentifier: String, Codable {
        case password = "password"
        case backup = "backup"
        case master = "master"

        func identifier(for keychainService: KeychainService) -> String {
            return "\(keychainService.rawValue).\(self.rawValue)"
        }
    }

    enum KeyType: UInt64 {
        case passwordSeed = 0
        case backupSeed = 1
    }

    static func create(context: LAContext?, completionHandler: @escaping (_ error: Error?) -> Void) {
        guard !hasKeys && !BackupManager.shared.hasKeys else {
            completionHandler(SeedError.exists)
            return
        }
        do {

            let seed = try Crypto.shared.generateSeed()
            let passwordSeed = try Crypto.shared.deriveKeyFromSeed(seed: seed, keyType: .passwordSeed, context: CRYPTO_CONTEXT)
            let backupSeed = try Crypto.shared.deriveKeyFromSeed(seed: seed, keyType: .backupSeed, context: CRYPTO_CONTEXT)

            BackupManager.shared.initialize(seed: backupSeed, context: context) { error in
                do {
                    if let error = error {
                        throw error
                    }
                    try Keychain.shared.save(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, secretData: seed)
                    try Keychain.shared.save(id: KeyIdentifier.password.identifier(for: .seed), service: .seed, secretData: passwordSeed)
                    try Keychain.shared.save(id: KeyIdentifier.backup.identifier(for: .seed), service: .seed, secretData: backupSeed)
                    completionHandler(nil)
                } catch {
                    BackupManager.shared.deleteAllKeys()
                    try? delete()
                    completionHandler(error)
                }
            }
        } catch {
            try? delete()
            completionHandler(error)
        }
    }

    #warning("Ask for authorization instead of throw if context is invalid")
    static func mnemonic() throws -> [String] {
        let seed = try Keychain.shared.get(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, context: nil)
        let checksumSize = seed.count / 4
        let bitstring = seed.bitstring + String(seed.sha256.first!, radix: 2).pad(toSize: 8).prefix(checksumSize)
        let wordlist = try self.localizedWordlist()

        return bitstring.components(withLength: 11).map({ wordlist[Int($0, radix: 2)!] })
    }
    
    static func validate(mnemonic: [String]) -> Bool {
        guard let (checksum, seed) = try? generateSeedFromMnemonic(mnemonic: mnemonic) else {
            return false
        }

        let checksumSize = seed.count / 4
        return checksum == String(seed.sha256.first!, radix: 2).pad(toSize: 8).prefix(checksumSize) || checksum == oldChecksum(seed: seed)
    }
    
    static func recover(context: LAContext, mnemonic: [String], completionHandler: @escaping (_ error: Error?) -> Void) {
        guard !hasKeys && !BackupManager.shared.hasKeys else {
            completionHandler(SeedError.exists)
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
            BackupManager.shared.deleteAllKeys()
            try? delete()
            completionHandler(error)
        }
    }

    static func getPasswordSeed(context: LAContext?) throws -> Data {
        return try Keychain.shared.get(id: KeyIdentifier.password.identifier(for: .seed), service: .seed, context: context)
    }

    static func getBackupSeed(context: LAContext?) throws -> Data {
        return try Keychain.shared.get(id: KeyIdentifier.backup.identifier(for: .seed), service: .seed, context: context)
    }

    static func delete() throws {
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
