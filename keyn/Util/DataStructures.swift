/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import Foundation


/*
 * Keyn messages go app <-> browser
 *
 * They always have a type so the app/browser can determine course of action.
 * There is one struct for requests, there are multiple for responses.
 */
enum KeynMessageType: Int, Codable {
    case pair = 0
    case login = 1
    case register = 2
    case change = 3
    case reset = 4          // Unused
    case add = 5
    case addAndChange = 6   // Unused
    case end = 7
    case acknowledge = 8
    case fill = 9
    case reject = 10
}

/*
 * Keyn Requests.
 *
 * Direction: browser -> app
 */
struct KeynRequest: Codable {
    let s: String?          // Site id (e.g. PPDHandle)
    let b: Int?             // Browser tab id
    let n: String?          // Site name
    let v: Bool?            // Value for change password confirmation
    let p: String?          // Password
    let u: String?          // Username
    let a: String?          // Account id
    let r: KeynMessageType  // One of the message types Keyn understands
}

/*
 * Keyn Responses.
 *
 * Direction: app -> browser
 */
struct KeynPairingResponse: Codable {
    let sessionID: String
    let pubKey: String
    let userID: String
    let sandboxed: Bool
    let type: KeynMessageType
}

struct KeynCredentialsResponse: Codable {
    let u: String?          // Username
    let p: String?          // Password
    let np: String?         // New password (for reset only! When registering p will be set)
    let b: Int              // Browser tab id
    let a: String?          // Account id (Only used with changePasswordRequests
    let o: String?          // OTP code
    let t: KeynMessageType  // One of the message types Keyn understands
}

struct PushNotification {
    let sessionID: String
    let siteID: String
    let siteName: String
    let browserTab: Int
    let currentPassword: String?
    let username: String?
    let type: KeynMessageType
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
