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
