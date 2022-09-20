//
//  WebAuthnTests.swift
//  ChiffCoreTests
//
//  Copyright: see LICENSE.md
//

import Foundation


import XCTest
import LocalAuthentication
import CryptoKit
import PromiseKit

@testable import ChiffCore

class WebAuthnTests: XCTestCase {

    override static func setUp() {
        super.setUp()

        var finished = false
        if !LocalAuthenticationManager.shared.isAuthenticated {
            LocalAuthenticationManager.shared.authenticate(reason: "Testing", withMainContext: true).done { result in
                finished = true
            }.catch { error in
                fatalError("Failed to get context: \(error.localizedDescription)")
            }
        } else {
            finished = true
        }

        while !finished {
            RunLoop.current.run(mode: .default, before: Date.distantFuture)
        }
    }

    override func setUp() {
        super.setUp()
        Keychain.shared = MockKeychain()
        TestHelper.createSeed()
    }

    override func tearDown() {
        super.tearDown()
        TestHelper.deleteLocalData()
    }

    // MARK: - Unit tests

    // TODO

    private func saveWebAuthn(id: String, webAuthn: WebAuthn, context: LAContext?) throws {
        let keyPair = try webAuthn.generateKeyPair(accountId: id, context: context)
        switch webAuthn.algorithm {
        case .edDSA:
            try Keychain.shared.save(id: id, service: .account(attribute: .webauthn), secretData: keyPair.privKey, objectData: keyPair.pubKey)
        case .ECDSA256:
            guard #available(iOS 13.0, *) else {
                throw WebAuthnError.notSupported
            }
            let privKey = try P256.Signing.PrivateKey(rawRepresentation: keyPair.privKey)
            try Keychain.shared.saveKey(id: id, key: privKey)
        case .ECDSA384:
            guard #available(iOS 13.0, *) else {
                throw WebAuthnError.notSupported
            }
            let privKey = try P384.Signing.PrivateKey(rawRepresentation: keyPair.privKey)
            try Keychain.shared.saveKey(id: id, key: privKey)
        case .ECDSA512:
            guard #available(iOS 13.0, *) else {
                throw WebAuthnError.notSupported
            }
            let privKey = try P521.Signing.PrivateKey(rawRepresentation: keyPair.privKey)
            try Keychain.shared.saveKey(id: id, key: privKey)
        }
    }

}
