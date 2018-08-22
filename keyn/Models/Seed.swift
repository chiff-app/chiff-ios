//
//  Seed.swift
//  keyn
//
//  Created by bas on 29/11/2017.
//  Copyright © 2017 keyn. All rights reserved.
//

import Foundation

struct Seed {
    static let keychainService = "io.keyn.seed"
    private enum KeyIdentifier: String, Codable {
        case password = "password"
        case backup = "backup"
        case master = "master"

        func identifier(for keychainService: String) -> String {
            return "\(keychainService).\(self.rawValue)"
        }
    }

    static func create() throws {
        let seed = try Crypto.sharedInstance.generateSeed()
        let passwordSeed = try Crypto.sharedInstance.deriveKeyFromSeed(seed: seed, keyType: .passwordSeed, context: KeyIdentifier.password.rawValue)
        let backupSeed = try Crypto.sharedInstance.deriveKeyFromSeed(seed: seed, keyType: .backupSeed, context: KeyIdentifier.backup.rawValue)

        try Keychain.sharedInstance.save(secretData: seed, id: KeyIdentifier.master.identifier(for: keychainService), service: keychainService)
        try Keychain.sharedInstance.save(secretData: passwordSeed, id: KeyIdentifier.password.identifier(for: keychainService), service: keychainService)
        try Keychain.sharedInstance.save(secretData: backupSeed, id: KeyIdentifier.backup.identifier(for: keychainService), service: keychainService)
    }


    static func mnemonic() throws -> [String] {
        let seed = try Keychain.sharedInstance.get(id: KeyIdentifier.master.identifier(for: keychainService), service: keychainService)
        let seedHash = try Crypto.sharedInstance.hash(seed).first!
        var bitstring = ""
        for byte in Array<UInt8>(seed) {
            bitstring += String(byte, radix: 2).pad(toSize: 8)
        }
        bitstring += String(String(seedHash, radix: 2).prefix(seed.count / 4)).pad(toSize: seed.count / 4)

        let wordlistData = try String(contentsOfFile: Bundle.main.path(forResource: "english_wordlist", ofType: "txt")!, encoding: .utf8)
        let wordlist = wordlistData.components(separatedBy: .newlines)

        var mnemonic = [String]()
        for word in bitstring.components(withLength: 11) {
            guard let index = Int(word, radix: 2) else {
                throw CryptoError.mnemonicConversion
            }
            mnemonic.append(wordlist[index])
        }

        return mnemonic
    }
    
    static func validate(mnemonic: [String]) -> Bool {
        guard let (checksum, seed) = try? generateSeedFromMnemonic(mnemonic: mnemonic) else {
            return false
        }
        
        guard let seedHash = try? Crypto.sharedInstance.hash(seed).first! else {
            return false
        }
        if checksum == String(String(seedHash, radix: 2).prefix(seed.count / 4)).pad(toSize: seed.count / 4) {
            return true
        }
        return false
    }
    
    static private func generateSeedFromMnemonic(mnemonic: [String]) throws -> (String, Data) {
        let wordlistData = try String(contentsOfFile: Bundle.main.path(forResource: "english_wordlist", ofType: "txt")!, encoding: .utf8)
        let wordlist = wordlistData.components(separatedBy: .newlines)
        
        var bitstring = ""
        for word in mnemonic {
            guard let index: Int = wordlist.index(of: word) else {
                throw CryptoError.mnemonicConversion
            }
            bitstring += String(index, radix: 2).pad(toSize: 11)
        }
        
        let checksum = bitstring.suffix(mnemonic.count / 3)
        let seedString = String(bitstring.prefix(bitstring.count - checksum.count))
        var seed = Data(capacity: seedString.count)
        for byteString in seedString.components(withLength: 8) {
            guard let byte = UInt8(byteString, radix: 2) else {
                throw CryptoError.mnemonicConversion
            }
            seed.append(byte)
        }
        
        return (String(checksum), seed)
    }

    static func recover(mnemonic: [String]) throws -> Bool {
        let (checksum, seed) = try generateSeedFromMnemonic(mnemonic: mnemonic)

        let seedHash = try Crypto.sharedInstance.hash(seed).first!
        guard checksum == String(String(seedHash, radix: 2).prefix(seed.count / 4)).pad(toSize: seed.count / 4) else {
            return false
        }


        let passwordSeed = try Crypto.sharedInstance.deriveKeyFromSeed(seed: seed, keyType: .passwordSeed, context: KeyIdentifier.password.rawValue)
        let backupSeed = try Crypto.sharedInstance.deriveKeyFromSeed(seed: seed, keyType: .backupSeed, context: KeyIdentifier.backup.rawValue)

        try Keychain.sharedInstance.save(secretData: seed, id: KeyIdentifier.master.identifier(for: keychainService), service: keychainService, label: "true")
        try Keychain.sharedInstance.save(secretData: passwordSeed, id: KeyIdentifier.password.identifier(for: keychainService), service: keychainService)
        try Keychain.sharedInstance.save(secretData: backupSeed, id: KeyIdentifier.backup.identifier(for: keychainService), service: keychainService)
        
        return true
    }

    static func getPasswordSeed() throws -> Data {
        return try Keychain.sharedInstance.get(id: KeyIdentifier.password.identifier(for: keychainService), service: keychainService)
    }

    static func getBackupSeed() throws -> Data {
        return try Keychain.sharedInstance.get(id: KeyIdentifier.backup.identifier(for: keychainService), service: keychainService)
    }

    static func exists() -> Bool {
        return Keychain.sharedInstance.has(id: KeyIdentifier.master.identifier(for: keychainService), service: keychainService)
    }

    static func delete() throws {
        try Keychain.sharedInstance.delete(id: KeyIdentifier.master.identifier(for: keychainService), service: keychainService)
        try Keychain.sharedInstance.delete(id: KeyIdentifier.backup.identifier(for: keychainService), service: keychainService)
        try Keychain.sharedInstance.delete(id: KeyIdentifier.password.identifier(for: keychainService), service: keychainService)
    }

    static func setBackedUp() throws {
        try Keychain.sharedInstance.update(id: KeyIdentifier.master.identifier(for: keychainService), service: keychainService, label: "true")
    }

    static func isBackedUp() throws -> Bool {
        guard let dataArray = try Keychain.sharedInstance.attributes(id: KeyIdentifier.master.identifier(for: keychainService), service: keychainService) else {
            return false
        }

        guard let label = dataArray[kSecAttrLabel as String] as? String else {
            return false
        }

        return label == "true"
    }
    
}
