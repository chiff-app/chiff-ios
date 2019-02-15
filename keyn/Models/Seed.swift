/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import Foundation

enum SeedError: Error {
    case mnemonicConversion
}

struct Seed {
    
    private static let keychainService = "io.keyn.seed"

    private enum KeyIdentifier: String, Codable {
        case password = "password"
        case backup = "backup"
        case master = "master"

        func identifier(for keychainService: String) -> String {
            return "\(keychainService).\(self.rawValue)"
        }
    }

    static func create() throws {
        let seed = try Crypto.shared.generateSeed()
        let passwordSeed = try Crypto.shared.deriveKeyFromSeed(seed: seed, keyType: .passwordSeed, context: KeyIdentifier.password.rawValue)
        let backupSeed = try Crypto.shared.deriveKeyFromSeed(seed: seed, keyType: .backupSeed, context: KeyIdentifier.backup.rawValue)

        try Keychain.shared.save(id: KeyIdentifier.master.identifier(for: keychainService), service: keychainService, secretData: seed, classification: .secret)
        try Keychain.shared.save(id: KeyIdentifier.password.identifier(for: keychainService), service: keychainService, secretData: passwordSeed, classification: .secret)
        try Keychain.shared.save(id: KeyIdentifier.backup.identifier(for: keychainService), service: keychainService, secretData: backupSeed, classification: .secret)
    }

    static func mnemonic() throws -> [String] {
        let seed = try Keychain.shared.get(id: KeyIdentifier.master.identifier(for: keychainService), service: keychainService)
        let seedHash = try Crypto.shared.hash(seed).first!
        var bitstring = seed.bitstring
        bitstring += String(String(seedHash, radix: 2).prefix(seed.count / 4)).pad(toSize: seed.count / 4) // Add checksum

        let wordlist = try self.wordlist()

        return bitstring.components(withLength: 11).map({ wordlist[Int($0, radix: 2)!] })
    }
    
    static func validate(mnemonic: [String]) -> Bool {
        guard let (checksum, seed) = try? generateSeedFromMnemonic(mnemonic: mnemonic) else {
            return false
        }
        
        guard let seedHash = try? Crypto.shared.hash(seed).first! else {
            return false
        }
        if checksum == String(String(seedHash, radix: 2).prefix(seed.count / 4)).pad(toSize: seed.count / 4) {
            return true
        }
        return false
    }
    
    static func recover(mnemonic: [String]) throws -> Bool {
        let (checksum, seed) = try generateSeedFromMnemonic(mnemonic: mnemonic)

        let seedHash = try Crypto.shared.hash(seed).first!
        guard checksum == String(String(seedHash, radix: 2).prefix(seed.count / 4)).pad(toSize: seed.count / 4) else {
            return false
        }


        let passwordSeed = try Crypto.shared.deriveKeyFromSeed(seed: seed, keyType: .passwordSeed, context: KeyIdentifier.password.rawValue)
        let backupSeed = try Crypto.shared.deriveKeyFromSeed(seed: seed, keyType: .backupSeed, context: KeyIdentifier.backup.rawValue)

        try Keychain.shared.save(id: KeyIdentifier.master.identifier(for: keychainService), service: keychainService, secretData: seed, label: "true", classification: .secret)
        try Keychain.shared.save(id: KeyIdentifier.password.identifier(for: keychainService), service: keychainService, secretData: passwordSeed, classification: .secret)
        try Keychain.shared.save(id: KeyIdentifier.backup.identifier(for: keychainService), service: keychainService, secretData: backupSeed, classification: .secret)
        
        return true
    }

    static func getPasswordSeed() throws -> Data {
        return try Keychain.shared.get(id: KeyIdentifier.password.identifier(for: keychainService), service: keychainService)
    }

    static func getBackupSeed() throws -> Data {
        return try Keychain.shared.get(id: KeyIdentifier.backup.identifier(for: keychainService), service: keychainService)
    }

    static func exists() -> Bool {
        return Keychain.shared.has(id: KeyIdentifier.master.identifier(for: keychainService), service: keychainService)
    }

    static func delete() throws {
        try Keychain.shared.delete(id: KeyIdentifier.master.identifier(for: keychainService), service: keychainService)
        try Keychain.shared.delete(id: KeyIdentifier.backup.identifier(for: keychainService), service: keychainService)
        try Keychain.shared.delete(id: KeyIdentifier.password.identifier(for: keychainService), service: keychainService)
    }

    static func setBackedUp() throws {
        try Keychain.shared.update(id: KeyIdentifier.master.identifier(for: keychainService), service: keychainService, label: "true")
    }

    static func isBackedUp() throws -> Bool {
        guard let dataArray = try Keychain.shared.attributes(id: KeyIdentifier.master.identifier(for: keychainService), service: keychainService) else {
            return false
        }

        guard let label = dataArray[kSecAttrLabel as String] as? String else {
            return false
        }

        return label == "true"
    }
    
    // MARK: - Private
    
    static private func wordlist() throws -> [String] {
        let wordlistData = try String(contentsOfFile: Bundle.main.path(forResource: "wordlist", ofType: "txt")!, encoding: .utf8)
        return wordlistData.components(separatedBy: .newlines)
    }
    
    static private func generateSeedFromMnemonic(mnemonic: [String]) throws -> (String, Data) {
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
        
        return (String(checksum), seed.data)
    }
}
