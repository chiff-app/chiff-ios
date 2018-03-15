//
//  PasswordGenerator.swift
//  keyn
//
//  Created by bas on 15/03/2018.
//  Copyright © 2018 keyn. All rights reserved.
//

import Foundation

class PasswordGenerator {

    static let sharedInstance = PasswordGenerator()
    private init() {} //This prevents others from using the default '()' initializer for this singleton class.


    func generatePassword(username: String, passwordIndex: Int, siteID: String, ppd: PPD?, offset: [Int]?) throws -> String {

        var length = 22
        var chars = [Character]()
        if let ppd = ppd, let properties = ppd.properties, let maxLength = properties.maxLength, let minLength = properties.minLength, let characterSets = ppd.characterSets {
            length = min(maxLength, 24)

            // If the password is less then 8 characters, current password generation may result in a integer overflow. Perhaps should be checked somewhere else.
            guard length >= 8 else {
                throw CryptoError.passwordGeneration
            }

            for characterSet in characterSets {
                if let characters = characterSet.characters {
                    chars.append(contentsOf: [Character](characters))
                }
            }
        }

        // TODO: Implement rejection sampling.
        let password = try generatePasswordCandidate(username: username, passwordIndex: passwordIndex, siteID: siteID, length: length, chars: chars, offset: offset)

        return password
    }

    func calculatePasswordOffset(username: String, passwordIndex: Int, siteID: String, ppd: PPD?, password: String) throws -> [Int] {

        // TODO: We should check first if password complies with PPD, otherwise throw error. Or use different function so custom passwords can be verified while typing

        var length = 22
        var chars = [Character]()
        if let ppd = ppd, let properties = ppd.properties, let maxLength = properties.maxLength, let minLength = properties.minLength, let characterSets = ppd.characterSets {
            // Get parameters from ppd
            length = min(maxLength, 24)

            // If the password is less then 8 characters, current password generation may result in a integer overflow. Perhaps should be checked somewhere else.
            guard length >= 8 else {
                throw CryptoError.passwordGeneration
            }

            for characterSet in characterSets {
                if let characters = characterSet.characters {
                    chars.append(contentsOf: [Character](characters))
                }
            }
        } else {
            // Use optimal fallback composition rules
            length = 22 // redundant, but for now for clarity
        }

        var characterIndices = [Int](repeatElement(chars.count, count: length))
        var index = 0

        // This is part of validating password: checking for disallowed characters
        for char in password {
            guard let characterIndex = chars.index(of: char) else {
                throw CryptoError.characterNotAllowed
            }
            characterIndices[index] = characterIndex
            index += 1
        }

        let key = try generateKey(username: username, passwordIndex: passwordIndex, siteID: siteID)

        let bitLength = length * Int(ceil(log2(Double(chars.count)))) + (128 + length - (128 % length))
        let byteLength = roundUp(n: bitLength, m: (length * 8)) / 8
        let keyData = try Crypto.sharedInstance.deterministicRandomBytes(seed: key, length: byteLength)

        let bytesPerChar = byteLength / length
        var keyDataIterator = keyData.makeIterator()
        var offsets = [Int]()

        // Generates the offset
        for index in 0..<length {
            var data = Data()
            var counter = 0

            // Add up bytevalues to value
            repeat {
                guard let byte = keyDataIterator.next() else {
                    throw CryptoError.keyGeneration
                }
                data.append(byte)
                counter += 1
            } while counter < bytesPerChar

            // Calculate offset and add to array
            let value: Int = data.withUnsafeBytes { $0.pointee }
            offsets.append((characterIndices[index] - value) % (chars.count + 1))
        }

        return offsets
    }

    // MARK: Private functions

    private func generatePasswordCandidate(username: String, passwordIndex: Int, siteID: String, length: Int, chars: [Character], offset: [Int]?) throws -> String {
        let key = try generateKey(username: username, passwordIndex: passwordIndex, siteID: siteID)

        // #bits N = L x ceil(log2(C)) + (128 + L - (128 % L), where L is password length and C is character set cardinality, see Horsch(2017), p90
        let bitLength = length * Int(ceil(log2(Double(chars.count)))) + (128 + length - (128 % length))
        let byteLength = roundUp(n: bitLength, m: (length * 8)) / 8 // Round to nearest multiple of L * 8, so we can use whole bytes
        let keyData = try Crypto.sharedInstance.deterministicRandomBytes(seed: key, length: byteLength)

        // Zero-offsets if no offset is given
        let modulus = offset == nil ? chars.count : chars.count + 1
        let offset = offset ?? Array<Int>(repeatElement(0, count: length))
        let bytesPerChar = byteLength / length
        var keyDataIterator = keyData.makeIterator()
        var password = ""

        // Generates the password
        for index in 0..<length {
            var data = Data()
            var counter = 0

            // Add up bytevalues to value
            repeat {
                guard let byte = keyDataIterator.next() else {
                    throw CryptoError.keyGeneration
                }
                data.append(byte)
                counter += 1
            } while counter < bytesPerChar

            // Choose character from value, taking offset into account
            let value: Int = data.withUnsafeBytes { $0.pointee }
            let characterValue = (value + offset[index]) % modulus
            if characterValue != chars.count {
                password += String(chars[characterValue])
            }
        }

        return password
    }

    private func roundUp(n: Int, m: Int) -> Int {
        return n >= 0 ? ((n + m - 1) / m) * m : (n / m) * m
    }


    private func generateKey(username: String, passwordIndex: Int, siteID: String) throws -> Data {
        guard let usernameData = username.data(using: .utf8),
            let siteData = siteID.data(using: .utf8) else {
                throw CryptoError.keyDerivation
        }

        // TODO: If siteID is Int, use that as index. siteData is then not necessary anymore.
        let siteKey = try Crypto.sharedInstance.deriveKey(keyData: Seed.getPasswordKey(), context: siteData)
        let key = try Crypto.sharedInstance.deriveKey(keyData: siteKey, context: usernameData, passwordIndex: passwordIndex)

        return key
    }
    
}
