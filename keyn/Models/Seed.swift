/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import Foundation

enum SeedError: KeynError {
    case mnemonicConversion
    case checksumFailed
}

struct Seed {
    
    static var hasKeys: Bool {
        return Keychain.shared.has(id: KeyIdentifier.master.identifier(for: .seed), service: .seed) &&
        Keychain.shared.has(id: KeyIdentifier.backup.identifier(for: .seed), service: .seed) &&
        Keychain.shared.has(id: KeyIdentifier.password.identifier(for: .seed), service: .seed)
    }

    static var paperBackupCompleted: Bool {
        guard let dataArray = try? Keychain.shared.attributes(id: KeyIdentifier.master.identifier(for: .seed), service: .seed) else {
            return false
        }

        guard let label = dataArray?[kSecAttrLabel as String] as? String else {
            return false
        }

        return label == "true"
    }

    private enum KeyIdentifier: String, Codable {
        case password = "password"
        case backup = "backup"
        case master = "master"

        func identifier(for keychainService: KeychainService) -> String {
            return "\(keychainService.rawValue).\(self.rawValue)"
        }
    }

    static func create() throws {
        let seed = try Crypto.shared.generateSeed()
        let passwordSeed = try Crypto.shared.deriveKeyFromSeed(seed: seed, keyType: .passwordSeed, context: KeyIdentifier.password.rawValue)
        let backupSeed = try Crypto.shared.deriveKeyFromSeed(seed: seed, keyType: .backupSeed, context: KeyIdentifier.backup.rawValue)

        try Keychain.shared.save(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, secretData: seed)
        try Keychain.shared.save(id: KeyIdentifier.password.identifier(for: .seed), service: .seed, secretData: passwordSeed)
        try Keychain.shared.save(id: KeyIdentifier.backup.identifier(for: .seed), service: .seed, secretData: backupSeed)
    }

    static func mnemonic() throws -> [String] {
        let seed = try Keychain.shared.get(id: KeyIdentifier.master.identifier(for: .seed), service: .seed)
        let checksumSize = seed.count / 4
        let bitstring = seed.bitstring + String(seed.sha256.first!, radix: 2).pad(toSize: 8).prefix(checksumSize)
        let wordlist = try self.wordlist()

        return bitstring.components(withLength: 11).map({ wordlist[Int($0, radix: 2)!] })
    }
    
    static func validate(mnemonic: [String]) -> Bool {
        guard let (checksum, seed) = try? generateSeedFromMnemonic(mnemonic: mnemonic) else {
            return false
        }

        let checksumSize = seed.count / 4
        return checksum == String(seed.sha256.first!, radix: 2).pad(toSize: 8).prefix(checksumSize) || checksum == oldChecksum(seed: seed)
    }
    
    static func recover(mnemonic: [String]) throws {
        let (checksum, seed) = try generateSeedFromMnemonic(mnemonic: mnemonic)
        let checksumSize = seed.count / 4
        guard checksum == String(seed.sha256.first!, radix: 2).pad(toSize: 8).prefix(checksumSize) || checksum == oldChecksum(seed: seed) else {
            throw SeedError.checksumFailed
        }

        let passwordSeed = try Crypto.shared.deriveKeyFromSeed(seed: seed, keyType: .passwordSeed, context: KeyIdentifier.password.rawValue)
        let backupSeed = try Crypto.shared.deriveKeyFromSeed(seed: seed, keyType: .backupSeed, context: KeyIdentifier.backup.rawValue)

        try Keychain.shared.save(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, secretData: seed, label: "true")
        try Keychain.shared.save(id: KeyIdentifier.password.identifier(for: .seed), service: .seed, secretData: passwordSeed)
        try Keychain.shared.save(id: KeyIdentifier.backup.identifier(for: .seed), service: .seed, secretData: backupSeed)
    }

    static func getPasswordSeed() throws -> Data {
        return try Keychain.shared.get(id: KeyIdentifier.password.identifier(for: .seed), service: .seed)
    }

    static func getBackupSeed() throws -> Data {
        return try Keychain.shared.get(id: KeyIdentifier.backup.identifier(for: .seed), service: .seed)
    }

    static func delete() throws {
        try Keychain.shared.delete(id: KeyIdentifier.master.identifier(for: .seed), service: .seed)
        try Keychain.shared.delete(id: KeyIdentifier.backup.identifier(for: .seed), service: .seed)
        try Keychain.shared.delete(id: KeyIdentifier.password.identifier(for: .seed), service: .seed)
    }

    static func setPaperBackupCompleted() throws {
        try Keychain.shared.update(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, label: "true")
    }
    
    // MARK: - Private

    static func wordlist() throws -> [String] {
        let wordlistData = try String(contentsOfFile: Bundle.main.path(forResource: "wordlist", ofType: "txt")!, encoding: .utf8)
        return wordlistData.components(separatedBy: .newlines)
    }
    
    static private func generateSeedFromMnemonic(mnemonic: [String]) throws -> (Substring, Data) {
        let wordlist = try self.wordlist()

        let bitstring = try mnemonic.reduce("") { (result, word) throws -> String in
            guard let index: Int = wordlist.index(of: word) else {
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
