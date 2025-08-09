
//
//  Crypto.swift
//  ChiffCore
//
//  Copyright: see LICENSE.md
//
import Foundation
import CryptoKit

// MARK: - ASN.1 DER Encoding Helper
struct ASN1DEREncoder {
    
    // ASN.1 Tags
    static let sequenceTag: UInt8 = 0x30
    static let integerTag: UInt8 = 0x02
    static let octetStringTag: UInt8 = 0x04
    static let objectIdentifierTag: UInt8 = 0x06
    static let contextSpecificTag1: UInt8 = 0x81  // [1] for public key
    
    // Ed25519 OID: 1.3.101.112
    static let ed25519OID: [UInt8] = [0x06, 0x03, 0x2B, 0x65, 0x70]
    
    static func encodeLength(_ length: Int) -> [UInt8] {
        if length < 0x80 {
            return [UInt8(length)]
        } else if length < 0x100 {
            return [0x81, UInt8(length)]
        } else if length < 0x10000 {
            return [0x82, UInt8(length >> 8), UInt8(length & 0xFF)]
        } else {
            // For longer lengths, extend as needed
            fatalError("Length too long for this implementation")
        }
    }
    
    static func encodeSequence(_ content: [UInt8]) -> [UInt8] {
        var result = [sequenceTag]
        result.append(contentsOf: encodeLength(content.count))
        result.append(contentsOf: content)
        return result
    }
    
    static func encodeInteger(_ value: [UInt8]) -> [UInt8] {
        var result = [integerTag]
        result.append(contentsOf: encodeLength(value.count))
        result.append(contentsOf: value)
        return result
    }
    
    static func encodeOctetString(_ value: [UInt8]) -> [UInt8] {
        var result = [octetStringTag]
        result.append(contentsOf: encodeLength(value.count))
        result.append(contentsOf: value)
        return result
    }
}

@available(iOS 13.0, *)
// MARK: - Ed25519 PKCS#8 Encoding
public extension Crypto {
    
    func encodeToPKCS8DER(privateKey: Data) throws -> Data {
        guard privateKey.count == 32 else {
            throw CryptoKitError.incorrectParameterSize
        }
        
        let privateKeyBytes = Array(privateKey)
        
        // PKCS#8 PrivateKeyInfo structure:
        // PrivateKeyInfo ::= SEQUENCE {
        //     version                   Version,
        //     privateKeyAlgorithm       PrivateKeyAlgorithmIdentifier,
        //     privateKey                PrivateKey,
        //     attributes           [0]  IMPLICIT Attributes OPTIONAL
        // }
        
        // Version: INTEGER 0
        let version = ASN1DEREncoder.encodeInteger([0x00])
        
        // Algorithm Identifier: SEQUENCE {
        //     algorithm               OBJECT IDENTIFIER,
        //     parameters              ANY DEFINED BY algorithm OPTIONAL
        // }
        let algorithmIdentifier = ASN1DEREncoder.encodeSequence(ASN1DEREncoder.ed25519OID)
        
        // For Ed25519, the private key is wrapped in an OCTET STRING
        // Ed25519PrivateKey ::= OCTET STRING (SIZE (32))
        let wrappedPrivateKey = ASN1DEREncoder.encodeOctetString(privateKeyBytes)
        
        // The privateKey field in PKCS#8 is itself an OCTET STRING containing the above
        let privateKeyField = ASN1DEREncoder.encodeOctetString(wrappedPrivateKey)
        
        // Combine all fields into the main SEQUENCE
        var pkcs8Content: [UInt8] = []
        pkcs8Content.append(contentsOf: version)
        pkcs8Content.append(contentsOf: algorithmIdentifier)
        pkcs8Content.append(contentsOf: privateKeyField)
        
        let pkcs8DER = ASN1DEREncoder.encodeSequence(pkcs8Content)
        
        return Data(pkcs8DER)
    }
    
    // Convenience method using CryptoKit's Curve25519.Signing.PrivateKey
    func encodeToPKCS8DER(cryptoKitKey: Curve25519.Signing.PrivateKey) throws -> Data {
        let rawKey = cryptoKitKey.rawRepresentation
        return try encodeToPKCS8DER(privateKey: rawKey)
    }
}
