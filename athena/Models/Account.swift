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
    static let keychainService = "com.athena.account"

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

        guard let password = try Crypto.sharedInstance.generatePassword(username: username, passwordIndex: passwordIndex, siteID: site.id, restrictions: restrictions).data(using: .utf8) else {
            throw KeychainError.stringEncoding
        }

        try Keychain.sharedInstance.save(password, id: id, service: Account.keychainService, attributes: accountData)
    }

    func password() throws -> String {
        let data = try Keychain.sharedInstance.get(id: id, service: Account.keychainService)

        guard let password = String(data: data, encoding: .utf8) else {
            throw KeychainError.unexpectedData
        }

        return password
    }

    mutating func updatePassword(restrictions: PasswordRestrictions) throws {
        passwordIndex += 1

        let newPassword = try Crypto.sharedInstance.generatePassword(username: username, passwordIndex: passwordIndex, siteID: site.id, restrictions: restrictions)

        guard let passwordData = newPassword.data(using: .utf8) else {
            throw KeychainError.stringEncoding
        }

        try Keychain.sharedInstance.update(passwordData, id: id, service: Account.keychainService)
    }

    func delete() throws {
        try Keychain.sharedInstance.delete(id: id, service: Account.keychainService)
    }

    static func all() throws -> [Account]? {
        guard let dataArray = try Keychain.sharedInstance.all(service: keychainService) else {
            return nil
        }

        var accounts = [Account]()
        let decoder = PropertyListDecoder()

        for dict in dataArray {
            guard let accountData = dict[kSecAttrGeneric as String] as? Data else {
                throw KeychainError.unexpectedData
            }
            accounts.append(try decoder.decode(Account.self, from: accountData))
        }
        return accounts
    }

}


