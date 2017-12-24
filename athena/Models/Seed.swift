//
//  Seed.swift
//  athena
//
//  Created by bas on 29/11/2017.
//  Copyright © 2017 athena. All rights reserved.
//

import Foundation

struct Seed {
    static let keychainService = "com.athena.seed"

    static func create() throws {
        try Keychain.sharedInstance.save(Crypto.sharedInstance.generateSeed(), id: keychainService, service: keychainService, attributes: nil)
    }

    static func mnemonic() throws -> [String] {
        let seed = try Keychain.sharedInstance.get(id: keychainService, service: keychainService)
        let seedHash = try Crypto.sharedInstance.hash(seed).first!
        var bitstring = ""
        for byte in Array<UInt8>(seed) {
            bitstring += pad(string: String(byte, radix: 2), toSize: 8)
        }
        bitstring += pad(string: String(String(seedHash, radix: 2).prefix(seed.count / 4)), toSize: seed.count / 4)

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

    static func recover(mnemonic: [String]) throws -> Bool {
        let wordlistData = try String(contentsOfFile: Bundle.main.path(forResource: "english_wordlist", ofType: "txt")!, encoding: .utf8)
        let wordlist = wordlistData.components(separatedBy: .newlines)

        var bitstring = ""
        for word in mnemonic {
            guard let index: Int = wordlist.index(of: word) else {
                throw CryptoError.mnemonicConversion
            }
            bitstring += pad(string: String(index, radix: 2), toSize: 11)
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

        let seedHash = try Crypto.sharedInstance.hash(seed).first!
        guard checksum == pad(string: String(String(seedHash, radix: 2).prefix(seed.count / 4)), toSize: seed.count / 4) else {
            return false
        }
        
        try Keychain.sharedInstance.save(seed, id: keychainService, service: keychainService, attributes: nil)
        
        return true
    }

    private static func pad(string : String, toSize: Int) -> String {
        var padded = string
        for _ in 0..<(toSize - string.count) {
            padded = "0" + padded
        }
        return padded
    }

    static func get() throws -> Data {
        return try Keychain.sharedInstance.get(id: keychainService, service: keychainService)
    }

    static func exists() -> Bool {
        return Keychain.sharedInstance.has(id: keychainService, service: keychainService)
    }

    static func delete() throws {
        try Keychain.sharedInstance.delete(id: keychainService, service: keychainService)
    }
    
}
