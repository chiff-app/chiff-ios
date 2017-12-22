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

    static func create() throws -> [String] {
        let seed = try Crypto.sharedInstance.generateSeed()
        try Keychain.sharedInstance.save(seed, id: keychainService, service: keychainService, attributes: nil)
        return try mnemonic()
    }

    static func mnemonic() throws -> [String] {
        let seed = try Keychain.sharedInstance.get(id: keychainService, service: keychainService)
        let seedHash = try Crypto.sharedInstance.hash(seed)
        let checksum: Data = seedHash.prefix(seed.count / 32) // Now only works for 256 bit-keys, access bits to use 128 bit
        var bitstring = ""
        for byte in Array<UInt8>(seed + checksum) {
            bitstring += pad(string: String(byte, radix: 2), toSize: 8)
        }

        let data = try String(contentsOfFile: Bundle.main.path(forResource: "english_wordlist", ofType: "txt")!, encoding: .utf8)
        let wordlist = data.components(separatedBy: .newlines)

        var mnemonic = [String]()
        for word in bitstring.components(withLength: 11) {
            guard let index = Int(word, radix: 2) else {
                throw CryptoError.mnemonicConversion
            }
            mnemonic.append(wordlist[index])
        }
        print(mnemonic.joined(separator: " "))

        return mnemonic
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
