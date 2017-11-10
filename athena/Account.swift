import Foundation
import CryptoSwift

/*
 * An account belongs to the user and can have one or more Sites.
 */
struct Account {

    var username: String
    var site: Site
    var passwordIndex = 0

    func password() -> String {
        // TODO
        // let seed = User.seed()
        let uniqueCombination = "SEED" + username + site.id + String(passwordIndex)

        guard let uniqueCombinationData = uniqueCombination.data(using: .utf8) else {
            fatalError("UniqueCombinationString cannot be converted to data.")
        }

        return self.generatePseudoDeterministicPassword(with: uniqueCombinationData)
    }

    func generatePseudoDeterministicPassword(with input: Data) -> String {
        let letters : NSString = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()_-+={[}]:;<,>.?/"
        var password = ""
        let hash = input.sha256()

        for (_, element) in hash.enumerated() {
            let index = Int(element) % letters.length
            var nextChar = letters.character(at: index)
            password += NSString(characters: &nextChar, length: 1) as String
        }

        return String(password.prefix(24))
    }

}
