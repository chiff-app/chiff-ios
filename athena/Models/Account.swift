import Foundation
import CryptoSwift

/*
 * An account belongs to the user and can have one or more Sites.
 */
struct Account {

    let id: String
    let username: String
    let site: Site
    var passwordIndex: Int
    let restrictions: PasswordRestrictions

    init(username: String, site: Site, passwordIndex: Int = 0, restrictions: PasswordRestrictions) throws {

        // Temporary generated storage ID for dummy data.
        let storageID = "\(site.id)\(username)".sha256()
        let index = storageID.index(storageID.startIndex, offsetBy: 8)
        id = String(storageID[..<index]) // TODO: how to get an ID?

        self.username = username
        self.site = site
        self.passwordIndex = passwordIndex
        self.restrictions = restrictions

        do {
            let password = try Crypto.generatePassword(username: username, passwordIndex: passwordIndex, siteID: site.id, restrictions: restrictions)
            // This should print storeKey error if keys are already in keychain, so if this is not the first time you run this config
            try Keychain.savePassword(password, with: "com.athena.passwords.\(id)")
        } catch {
            print(error)
        }

    }

    func password() throws -> String {
        return try Keychain.getPassword(with: "com.athena.passwords.\(id)")
    }

    mutating func updatePassword(restrictions: PasswordRestrictions) throws {
        passwordIndex += 1
        let newPassword = try Crypto.generatePassword(username: username, passwordIndex: passwordIndex, siteID: site.id, restrictions: restrictions)
        print(newPassword)
        // TODO: update password in keychain
    }

    func deletePassword() throws {
        try Keychain.deletePassword(with: "com.athena.passwords.\(id)")
    }

}

struct PasswordRestrictions {
    let length: Int
    let characters: [Characters]

    enum Characters {
        case lower
        case upper
        case numbers
        case symbols
    }
}
