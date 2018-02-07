import Foundation

/*
 * A site can have multiple URLs (e.g. live.com and hotmail.com).
 */
struct Site: Codable {

    var name: String
    var id: String
    var urls: [String]
    var restrictions: PasswordRestrictions

    // TODO:
    // Get Site object from some persistent storage or online database. This is sample data
    static func get(id: String) -> Site? {
        let restrictions = PasswordRestrictions(length: 24, characters: [.lower, .numbers, .upper, .symbols])
        var sampleSites = [Site]()

        sampleSites.append(Site(name: "LinkedIn", id: "0", urls: ["https://www.linkedin.com"], restrictions: restrictions))
        sampleSites.append(Site(name: "Gmail", id: "1", urls: ["https://gmail.com/login"], restrictions: restrictions))
        sampleSites.append(Site(name: "ProtonMail", id: "2", urls: ["https://mail.protonmail.com/login"], restrictions: restrictions))
        sampleSites.append(Site(name: "University of London", id: "3", urls: ["https://my.londoninternational.ac.uk/login"], restrictions: restrictions))
        sampleSites.append(Site(name: "Github", id: "4", urls: ["https://github.com/login"], restrictions: restrictions))

        if Int(id)! >= sampleSites.count {
            return nil
        } else {
            return sampleSites[Int(id)!]
        }
    }

}
