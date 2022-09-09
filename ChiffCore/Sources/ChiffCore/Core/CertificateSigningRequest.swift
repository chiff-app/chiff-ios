//
//  CertificateSigningRequest.swift
//  ChiffCore
//
//  Copyright: see LICENSE.md
//

#if os(iOS)
import UIKit
import CryptoKit
import DeviceCheck
import PromiseKit
import LocalAuthentication

@available(iOS 13.0, *)
public struct CertificateSigningRequest {

    let keypair: SecureEnclave.P256.Signing.PrivateKey
    var data: Data

    private let header: [UInt8] = [0x02, 0x01, 0x00, 0x30, 0x6a]
    private let organizationalUnitName: [UInt8] = [0x31, 0x22, 0x30, 0x20, 0x06, 0x03, 0x55, 0x04, 0x0b, 0x0c, 0x19, 0x41, 0x75, 0x74, 0x68, 0x65, 0x6e, 0x74, 0x69, 0x63, 0x61, 0x74, 0x6f, 0x72, 0x20, 0x41, 0x74, 0x74, 0x65, 0x73, 0x74, 0x61, 0x74, 0x69, 0x6f, 0x6e]
    private let commonName: [UInt8] = [0x31, 0x22, 0x30, 0x20, 0x06, 0x03, 0x55, 0x04, 0x03, 0x0c, 0x19, 0x43, 0x68, 0x69, 0x66, 0x66, 0x20, 0x46, 0x49, 0x44, 0x4f, 0x20, 0x41, 0x74, 0x74, 0x65, 0x73, 0x74, 0x61, 0x74, 0x69, 0x6f, 0x6e, 0x20, 0x76, 0x31]
    private let country: [UInt8] = [0x31, 0x0b, 0x30, 0x09, 0x06, 0x03, 0x55, 0x04, 0x06, 0x13, 0x02, 0x4e, 0x4c]
    private let organizationName: [UInt8] = [0x31, 0x13, 0x30, 0x11, 0x06, 0x03, 0x55, 0x04, 0x0a, 0x0c, 0x0a, 0x43, 0x68, 0x69, 0x66, 0x66, 0x20, 0x42, 0x2e, 0x56, 0x2e]
    private let extensions: [UInt8] = [0xa0, 0x42, 0x30, 0x40, 0x06, 0x09, 0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x09, 0x0e, 0x31, 0x33, 0x30, 0x31, 0x30, 0x0c, 0x06, 0x03, 0x55, 0x1d, 0x13, 0x01, 0x01, 0xff, 0x04, 0x02, 0x30, 0x00, 0x30, 0x21, 0x06, 0x0b, 0x2b, 0x06, 0x01, 0x04, 0x01, 0x82, 0xe5, 0x1c, 0x01, 0x01, 0x04, 0x04, 0x12, 0x04, 0x10]
    private let signatureHeader: [UInt8] = [0x30, 0x0a, 0x06, 0x08, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x04, 0x03, 0x02]

    @available(iOS 14.0, *)
    init(keypair: SecureEnclave.P256.Signing.PrivateKey) throws {
        self.keypair = keypair
        self.data = Data()
        appendSubjectInfo(data: &data)
        data.append(contentsOf: keypair.publicKey.derRepresentation)
        data.append(contentsOf: extensions)
        data.append(WebAuthn.AAGUID)
        try embedInSequence(&data)
        try appendSignature(data: &data, keypair: keypair)
        try embedInSequence(&data)
    }

    private func appendSubjectInfo(data: inout Data) {
        data.append(contentsOf: header)
        data.append(contentsOf: organizationalUnitName)
        data.append(contentsOf: commonName)
        data.append(contentsOf: country)
        data.append(contentsOf: organizationName)
    }

    private func appendSignature(data: inout  Data, keypair: SecureEnclave.P256.Signing.PrivateKey) throws {
        let signature = try keypair.signature(for: data)
        data.append(contentsOf: signatureHeader)
        var signatureData = Data()
        signatureData.append(0x00)
        signatureData.append(signature.derRepresentation)
        try embedInBitstring(&signatureData)
        data.append(signatureData)
    }

    private func embedInBitstring(_ data: inout Data) throws {
        var newData = Data()
        newData.append(0x03)
        try newData.append(getLength(&data))
        newData.append(data)
        data = newData
    }

    private func embedInSequence(_ data: inout Data) throws {
        var newData = Data()
        newData.append(0x30)
        try newData.append(getLength(&data))
        newData.append(data)
        data = newData
    }

    private func getLength(_ data: inout Data) throws -> Data {
        let length = data.count
        var lengthData = Data()
        switch length {
        case 0..<128:
            lengthData.append(UInt8(length))
        case 128..<256:
            lengthData.append(UInt8(0x81))
            lengthData.append(UInt8(length & 0xff))
        case 256..<0x8000:
            lengthData.append(UInt8(0x82))
            lengthData.append((UInt8(length >> 8) & 0xff))
            lengthData.append(UInt8(length & 0xff))
        default:
            throw AttestationError.lengthOverflow
        }
        return lengthData
    }

}
#endif
