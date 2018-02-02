import Foundation

/*
 * A site can have multiple URLs (e.g. live.com and hotmail.com).
 */
struct Site: Codable {

    var name: String
    var id: String
    var urls: [String]
    var restrictions: PasswordRestrictions

    static func get(id: String) -> Site {
        // TODO: get Site object from some persistent storage or online database. This is sample data

        let restrictions = PasswordRestrictions(length: 24, characters: [.lower, .numbers, .upper, .symbols])
        var sampleSites = [Site]()
        sampleSites.append(Site(name: "LinkedIn", id: "0", urls: ["https://www.linkedin.com"], restrictions: restrictions))
        sampleSites.append(Site(name: "Gmail", id: "1", urls: ["https://gmail.com/login"], restrictions: restrictions))
        sampleSites.append(Site(name: "ProtonMail", id: "2", urls: ["https://mail.protonmail.com/login"], restrictions: restrictions))
        sampleSites.append(Site(name: "University of London", id: "3", urls: ["https://my.londoninternational.ac.uk/login"], restrictions: restrictions))
        sampleSites.append(Site(name: "Github", id: "4", urls: ["https://github.com/login"], restrictions: restrictions))
        return sampleSites[Int(id)!]
    }

}
