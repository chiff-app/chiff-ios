//
//  File.swift
//  
//
//  Created by Bas Doorn on 24/03/2021.
//

import Foundation
import LocalAuthentication
import PromiseKit
@testable import ChiffCore

class MockKeychain: KeychainProtocol {

    var data = [String: (Data?,Any?)]()
    var keys  = [String: SecKeyConvertible]()

    func save(id identifier: String, service: KeychainService, secretData: Data?, objectData: Data?, label: String?) throws {
        let key = "\(service.service)-\(identifier)"
        guard data[key] == nil else {
            throw KeychainError.duplicateItem
        }
        data[key] = (secretData, objectData)
    }

    func get(id identifier: String, service: KeychainService, context: LAContext?) throws -> Data? {
        try checkContext(context: context)
        return data["\(service.service)-\(identifier)"]?.0
    }

    func get(id identifier: String, service: KeychainService, reason: String, with context: LAContext?, authenticationType type: AuthenticationType) -> Promise<Data?> {
        do {
            try checkContext(context: context)
            return .value(try self.get(id: identifier, service: service, context: nil))
        } catch {
            return Promise(error: error)
        }
    }

    func attributes(id identifier: String, service: KeychainService, context: LAContext?) throws -> Data? {
        try checkContext(context: context)
        if let (_, object) = data["\(service.service)-\(identifier)"] {
            guard let object = object else {
                throw KeychainError.notFound
            }
            guard let dataObject = object as? Data else {
                throw KeychainError.unexpectedData
            }
            return dataObject
        } else {
            return nil
        }
    }

    func all(service: KeychainService, context: LAContext?, label: String?) throws -> [[String : Any]]? {
        try checkContext(context: context)
        return data.filter({ $0.key.hasPrefix(service.service) }).map { [
            kSecAttrGeneric as String: $0.value.1 as Any,
            kSecAttrAccount as String: String($0.key.dropFirst(service.service.count + 1))
        ] }
    }

    func update(id identifier: String, service: KeychainService, secretData: Data?, objectData: Data?, context: LAContext?) throws {
        try checkContext(context: context)
        guard secretData != nil || objectData != nil else {
            throw KeychainError.noData
        }
        if let (secret, object) = data["\(service.service)-\(identifier)"] {
            data["\(service.service)-\(identifier)"] = (secretData ?? secret, objectData ?? object)
        } else {
            throw KeychainError.notFound
        }
    }

    func has(id identifier: String, service: KeychainService, context: LAContext?) -> Bool {
        return data["\(service.service)-\(identifier)"] != nil
    }

    func delete(id identifier: String, service: KeychainService) throws {
        guard try get(id: identifier, service: service) != nil else {
            throw KeychainError.notFound
        }
        data.removeValue(forKey: "\(service.service)-\(identifier)")
    }

    func deleteAll(service: KeychainService, label: String?) {
        for item in data {
            if item.key.hasPrefix(service.service) {
                data.removeValue(forKey: item.key)
            }
        }
    }

    func saveKey<T>(id identifier: String, key: T) throws where T : SecKeyConvertible {
        keys[identifier] = key
    }

    func getKey<T>(id identifier: String, context: LAContext?) throws -> T? where T : SecKeyConvertible {
        try checkContext(context: context)
        return keys[identifier] as? T
    }

    func deleteKey(id identifier: String) throws {
        keys.removeValue(forKey: identifier)
    }

    func deleteAllKeys() {
        keys.removeAll()
    }

    func migrate(context: LAContext?) {
        print("TODO: Add migration")
    }

    private func checkContext(context: LAContext?) throws {
        if let context = context {
            var authError: NSError?
            guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &authError) else {
                throw KeychainError.interactionNotAllowed
            }
        }
    }

}
