//
//  WebAuthn+Attestation.swift
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

enum AttestationError: Error {
    case lengthOverflow
    case notSupported
}

@available(iOS 13.0, *) fileprivate typealias PrivateKey = SecureEnclave.P256.Signing.PrivateKey

@available(iOS 14.0, *)
public struct Attestation {

    private static var service: DCAppAttestService {
        return DCAppAttestService.shared
    }

    /// Attest the integrity of this device to the back-end.
    ///
    /// This is primarily used to be able to do attestation for WebAuthn. Only when device attestation is succesful, the back-end
    /// will return an attestation certificate chain when creating WebAuthn credentials.
    public static func attestDevice() -> Promise<Void> {
        guard Properties.attestationKeyID == nil,
              let deviceId = UIDevice.current.identifierForVendor?.uuidString,
              service.isSupported else {
            return .value(())
        }
        return firstly {
            try API.shared.signedRequest(path: "users/\(Seed.publicKey())/devices/\(deviceId)/attestation", method: .get, privKey: Seed.privateKey(), message: ["id": deviceId])
        }.then { (result: JSONObject) -> Promise<(String, [String: Any])> in
            guard let challenge = result["challenge"] as? String else {
                throw CodingError.unexpectedData
            }
            let clientData: [String: Any] = [
                "pubkey": try Seed.publicKey(),
                "challenge": challenge
            ]
            return service.generateKey().map { ($0, clientData) }
        }.then { (id: String, clientData: [String: Any]) -> Promise<(Data, String, String)> in
            let jsonData = try JSONSerialization.data(withJSONObject: clientData, options: [])
            return service.attestKey(id, clientDataHash: jsonData.sha256).map { ($0, jsonData.base64, id) }
        }.then { (attestation: Data, clientData: String, id: String) -> Promise<String>  in
            let data: [String: Any] = [
                "clientData": clientData,
                "keyID": id,
                "attestationObject": attestation.base64
            ]
            let jsonData = try JSONSerialization.data(withJSONObject: data, options: [])
            return try API.shared.signedRequest(path: "users/\(Seed.publicKey())/devices/\(deviceId)/attestation", method: .post, privKey: Seed.privateKey(), message: ["hash": jsonData.sha256.hexEncodedString(), "id": deviceId], body: jsonData).asVoid().map { id }
        }.done { id in
            Properties.attestationKeyID = id
        }.log("Error submitting attestation key")
    }

    /// Generate a signed attestation x5c certiticate chain for a provided WebAuthn keypair.
    ///
    /// Will only succeed if the app has previously called `attestDevice()`.
    /// - Parameter keypair: The Keypair that needs to be attested.
    /// - Returns: A list of base64-encoded certificates, moving up the chain.
    public static func attestWebAuthnKeypair(keypair: SecureEnclave.P256.Signing.PrivateKey) -> Promise<[String]> {
        guard service.isSupported,
              let id = Properties.attestationKeyID,
              let deviceId = UIDevice.current.identifierForVendor?.uuidString else {
            return Promise(error: AttestationError.notSupported)
        }
        return firstly { () -> Promise<JSONObject> in
            try API.shared.signedRequest(path: "users/\(Seed.publicKey())/devices/\(deviceId)/assertion", method: .get, privKey: Seed.privateKey(), message: ["id": deviceId])
        }.then { (result: JSONObject) -> Promise<(Data, String)> in
            guard let challenge = result["challenge"] as? String else {
                throw CodingError.unexpectedData
            }
            let csr = try CertificateSigningRequest(keypair: keypair)
            let clientData: [String: Any] = [
                "pubkey": try Seed.publicKey(),
                "challenge": challenge,
                "csr": csr.data.base64
            ]
            let jsonData = try JSONSerialization.data(withJSONObject: clientData, options: [])
            return service.generateAssertion(id, clientDataHash: jsonData.sha256).map { ($0, jsonData.base64) }
        }.then { (assertion: Data, clientData: String) -> Promise<[String]>  in
            let data: [String: Any] = [
                "clientData": clientData,
                "assertion": assertion.base64
            ]
            let jsonData = try JSONSerialization.data(withJSONObject: data, options: [])
            return try API.shared.signedRequest(path: "users/\(Seed.publicKey())/devices/\(deviceId)/assertion", method: .post, privKey: Seed.privateKey(), message: ["hash": jsonData.sha256.hexEncodedString(), "id": deviceId], body: jsonData)
        }.log("Error attesting WebAuthn keypair")
    }

}
#endif
