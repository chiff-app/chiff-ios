import Foundation

/*
 * A site can have multiple URLs (e.g. live.com and hotmail.com).
 */
struct Site {

    var name: String
    var id: String
    var urls: [String]

    // How will be store this?
    // var passwordRequirements: String?

}
