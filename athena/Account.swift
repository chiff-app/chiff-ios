import Foundation
import CryptoSwift

/*
 * No definitive code
 */
struct Account {

    var username: String
    var site: Site
    let SEED = "THISISASEED"
    var passwordIndex = "1"

    func password() -> String {
        let uniqueCombination = SEED + username + site.id + passwordIndex
        return self.generatePseudoDeterministicPassword(with: uniqueCombination.data(using: .utf8))
    }

    func generatePseudoDeterministicPassword(with input: Data?) -> String {
        let letters : NSString = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()_-+={[}]:;<,>.?/"
        var password = ""
        let hash = input!.sha256()

        for (_, element) in hash.enumerated() {
            let index = Int(element) % letters.length
            var nextChar = letters.character(at: index)
            password += NSString(characters: &nextChar, length: 1) as String
        }

        return String(password.prefix(25))
    }

}
