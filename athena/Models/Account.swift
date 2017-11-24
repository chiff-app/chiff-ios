import Foundation
import CryptoSwift

/*
 * An account belongs to the user and can have one or more Sites.
 */
struct Account: Codable {

    let id: String
    let username: String
    let site: Site
    var passwordIndex: Int
    let restrictions: PasswordRestrictions

    init(username: String, site: Site, passwordIndex: Int = 0, restrictions: PasswordRestrictions?) {

        // Temporary generated storage ID for dummy data.
        let storageID = "\(site.id)\(username)".sha256()
        let index = storageID.index(storageID.startIndex, offsetBy: 8)
        id = String(storageID[..<index]) // TODO: how to get an ID?

        self.username = username
        self.site = site
        self.passwordIndex = passwordIndex
        self.restrictions = restrictions ?? site.restrictions // Use site default restrictions of no custom restrictions are provided

    }

    func save() throws {
        // This should print storeKey error if keys are already in keychain, so if this is not the first time you run this config
        let accountData = try PropertyListEncoder().encode(self)
        try Keychain.savePassword(try Crypto.generatePassword(username: username, passwordIndex: passwordIndex, siteID: site.id, restrictions: restrictions), account: accountData, with: id)
    }

    func password() throws -> String {
        return try Keychain.getPassword(with: id)
    }

    mutating func updatePassword(restrictions: PasswordRestrictions) throws {
        passwordIndex += 1
        let newPassword = try Crypto.generatePassword(username: username, passwordIndex: passwordIndex, siteID: site.id, restrictions: restrictions)
        try Keychain.updatePassword(newPassword, with: id)
    }

    func deleteAccount() throws {
        try Keychain.deletePassword(with: id)
    }

}


