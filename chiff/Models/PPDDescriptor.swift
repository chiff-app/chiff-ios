//
//  PPDDescriptor.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import Foundation
import PromiseKit

struct PPDDescriptor: Codable {
    let id: String
    let url: String
    let name: String
    let redirects: [String]

    /// Get a list of PPD decriptors.
    /// - Parameter organisationKeyPair: Optionally, an organisation keypair if organisational PPDs should be checked as well.
    /// - Returns: A list of PPD descriptors.
    static func get(organisationKeyPair: KeyPair?) -> Promise<[PPDDescriptor]> {
        return firstly { () -> Promise<[JSONObject]> in
            if let keyPair = organisationKeyPair {
                return API.shared.signedRequest(path: "organisations/\(keyPair.pubKey.base64)/ppd", method: .get, privKey: keyPair.privKey)
            } else {
                return API.shared.request(path: "ppd", method: .get)
            }
        }.map { result -> [PPDDescriptor] in
            return try result.map {
                let jsonData = try JSONSerialization.data(withJSONObject: $0, options: [])
                return try JSONDecoder().decode(PPDDescriptor.self, from: jsonData)
            }
        }
    }
}
