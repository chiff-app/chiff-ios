//
//  Crypto+ECDSA.swift
//  ChiffCore
//
//  Copyright: see LICENSE.md
//

import Foundation
import CryptoKit
import LocalAuthentication

@available(iOS 13.0, *)
public extension Crypto {

    /// Create a ECDSA signing keypair. This is used for WebAuthn.
    /// - Parameter seed: Optionally, the seed to use for the private key. Will be randomly generated if not provided.
    /// - Returns: The keypair.
    func createECDSASigningKeyPair(seed: Data?, algorithm: WebAuthnAlgorithm) throws -> KeyPair {
        var seedData: Data?
        if let seed = seed {
            seedData = try deterministicRandomBytes(seed: seed, length: algorithm.keyLength)
        }
        switch algorithm {
        case .ECDSA256:
            let privKey = seedData != nil ? try P256.Signing.PrivateKey(rawRepresentation: seedData!) : P256.Signing.PrivateKey()
            return KeyPair(pubKey: privKey.publicKey.rawRepresentation, privKey: privKey.rawRepresentation)
        case .ECDSA384:
            let privKey = seedData != nil ? try P384.Signing.PrivateKey(rawRepresentation: seedData!) : P384.Signing.PrivateKey()
            return KeyPair(pubKey: privKey.publicKey.rawRepresentation, privKey: privKey.rawRepresentation)
        case .ECDSA512:
            // 65 bytes are generated and prepended with 1 byte of zeroes
            let privKey = seedData != nil ? try P521.Signing.PrivateKey(rawRepresentation: Data(count: 1) + seedData!) : P521.Signing.PrivateKey()
            return KeyPair(pubKey: privKey.publicKey.rawRepresentation, privKey: privKey.rawRepresentation)
        default:
            throw CryptoError.wrongSigningFunction
        }
    }

    /// Create a ECDSA signing keypair in the secure enclave.
    /// - Parameter seed: The `LocalAuthenticationContext`. Will try to use main context if not provided
    /// - Returns: The keypair.
    func createSecureEnclaveECDSASigningKeyPair(context: LAContext?) throws -> SecureEnclave.P256.Signing.PrivateKey {
        let access = SecAccessControlCreateWithFlags(kCFAllocatorDefault, // Use the default allocator.
                                                     kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                                                     .privateKeyUsage,
                                                     nil)! // Ignore any error.
        return try SecureEnclave.P256.Signing.PrivateKey(compactRepresentable: true,
                                                                accessControl: access,
                                                                authenticationContext: context ?? LocalAuthenticationManager.shared.mainContext)
    }


}
