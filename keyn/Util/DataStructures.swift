/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import Foundation

// Used by Session
struct PairingResponse: Codable {
    let sessionID: String
    let pubKey: String
    let deviceEndpoint: String
    let userID: String
}

struct KeynMessage: Codable {
    let s: String?          // PPDHandle
    let r: KeynMessageType  // One of the message types Keyn understands
    let b: Int?             // Browser tab id
    let n: String?          // Site name
    let v: Bool?            // Value for change password confirmation
    let p: String?          // Old password
    let u: String?          // Possible username
    let a: String?          // Account id
}

enum KeynMessageType: Int, Codable {
    case pair
    case login
    case register
    case change
    case reset
    case add
    case addAndChange
    case end
    case acknowledge
    case fill
}

struct CredentialsResponse: Codable {
    let u: String?       // Username
    let p: String?      // Password
    let np: String?     // New password (for reset only! When registering p will be set)
    let b: Int
    let a: String?      // AccountID. Only used with changePasswordRequests
    let o: String?      // OTP code
}

struct PushNotification {
    let sessionID : String
    let siteID: String
    let siteName: String
    let browserTab: Int
    let currentPassword: String?
    let requestType: KeynMessageType
    let username: String?
}

enum KeyType: UInt64 {
    case passwordSeed, backupSeed
}

enum CodingError: KeynError {
    case stringEncoding
    case stringDecoding
    case unexpectedData
}

struct KeyPair {
    let pubKey: Data
    let privKey: Data
}
