//
//  WebAuthn.swift
//  keyn
//
//  Created by Bas Doorn on 20/02/2020.
//  Copyright © 2020 keyn. All rights reserved.
//

import Foundation
import LocalAuthentication
import CryptoKit

enum WebAuthnError: KeynError {
    case wrongRpId
    case notSupported
    case wrongAlgorithm
}

enum WebAuthnAlgorithm: Int, Codable {
    case EdDSA = -8
    case ECDSA = -7
}

struct WebAuthn: Codable {
    let id: String // rpId
    let algorithm: WebAuthnAlgorithm
    let salt: UInt64
    var counter: Int = 0

    static let CRYPTO_CONTEXT = "webauthn"

    init(id: String, algorithms: [WebAuthnAlgorithm]) throws {
        var algorithm: WebAuthnAlgorithm?
        if #available(iOS 13.0, *) {
            algorithm = algorithms.first
        } else if algorithms.contains(.EdDSA) {
            algorithm = .EdDSA
        }
        guard let acceptedAlgorithm = algorithm else {
            throw WebAuthnError.notSupported
        }
        self.algorithm = acceptedAlgorithm
        self.id = id
        var salt: UInt64 = 0
        _ = try withUnsafeMutableBytes(of: &salt, { try Crypto.shared.generateSeed(length: 8).copyBytes(to: $0) } )
        self.salt = salt
    }

    func generateKeyPair(accountId: String, context: LAContext?) throws -> KeyPair {
        var value: UInt64 = 0
        _ = withUnsafeMutableBytes(of: &value, { id.sha256Data.copyBytes(to: $0, from: 0..<8) } )
        let siteKey = try Crypto.shared.deriveKey(keyData: try Seed.getWebAuthnSeed(context: context), context: Self.CRYPTO_CONTEXT, index: value)
        let key = try Crypto.shared.deriveKey(keyData: siteKey, context: String(accountId.sha256Data.base64.prefix(8)), index: salt)
        var keyPair: KeyPair
        switch algorithm {
        case .EdDSA: keyPair = try Crypto.shared.createSigningKeyPair(seed: key)
        case .ECDSA:
            if #available(iOS 13.0, *) {
                keyPair = try Crypto.shared.createECDSASigningKeyPair(seed: key)
            } else {
                // Should only occur in the unlikely case that someone downgrades iOS version after initializing.
                throw WebAuthnError.notSupported
            }
        }
        return keyPair
    }

    mutating func sign(challenge: String, rpId: String, privKey: Data) throws -> (String, Int) {
        guard rpId == id else {
            throw WebAuthnError.wrongRpId
        }
        guard algorithm == .EdDSA else {
            throw WebAuthnError.wrongAlgorithm
        }
        let challengeData = try Crypto.shared.convertFromBase64(from: challenge)
        let data = try createAuthenticatorData() + challengeData
        let signature = try Crypto.shared.signature(message: data, privKey: privKey)
        return (signature.base64, counter)
    }

    @available(iOS 13.0, *)
    mutating func sign(challenge: String, rpId: String, privKey: P256.Signing.PrivateKey) throws -> (String, Int) {
        guard rpId == id else {
            throw WebAuthnError.wrongRpId
        }
        guard algorithm == .ECDSA else {
            throw WebAuthnError.wrongAlgorithm
        }
        let challengeData = try Crypto.shared.convertFromBase64(from: challenge)
        let data = try createAuthenticatorData() + challengeData
        let signature = try privKey.signature(for: data)
        return (signature.derRepresentation.base64, counter)
    }

        // TODO: Implement attestation
    //    mutating func signAttestation(rpId: String, challenge: String) throws -> (String, Int) {
    //        guard let rp = self.site.rpId, rpId == rp else {
    //            throw AccountError.wrongRpId
    //        }
    //        let challengeData = try Crypto.shared.convertFromBase64(from: challenge)
    //        guard let privKey = try Keychain.shared.get(id: id, service: .webauthn) else {
    //            throw KeychainError.notFound
    //        }
    //        let idData = try Crypto.shared.fromHex(id)
    //        var data = try createAuthenticatorData(rpId: rpId)
    //        data.append(UInt8((idData.count >> 8) & 0xff))
    //        data.append(UInt8(idData.count & 0xff))
    //
    //
    //        data.append(challengeData)
    //        let signature = try Crypto.shared.signature(message: data, privKey: privKey)
    //
    //        return (signature.base64, webAuthnCounter)
    //    }

    // MARK: - Private functions

    private mutating func createAuthenticatorData() throws -> Data {
        counter += 1
        var data = Data()
        data.append(id.sha256Data)
        data.append(0x05) // UP + UV flags
        data.append(UInt8((counter >> 24) & 0xff))
        data.append(UInt8((counter >> 16) & 0xff))
        data.append(UInt8((counter >> 8) & 0xff))
        data.append(UInt8((counter >> 0) & 0xff))
        return data
    }
    
}

