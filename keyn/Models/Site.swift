import Foundation

/*
 * A site can have multiple URLs (e.g. live.com and hotmail.com).
 */
struct Site: Codable {

    var name: String
    var id: Int
    var urls: [String]
    var ppd: PPD?

    // TODO:
    // Get Site object from some persistent storage or online database. This is sample data
    static func get(id: Int) -> Site? {
        var sampleSites = [Site]()

        sampleSites.append(Site(name: "LinkedIn", id: 0, urls: ["https://www.linkedin.com"], ppd: getSamplePPD(id: id)))
        sampleSites.append(Site(name: "Gmail", id: 1, urls: ["google.com", "accounts.google.com"], ppd: getSamplePPD(id: id)))
        sampleSites.append(Site(name: "ProtonMail", id: 2, urls: ["https://mail.protonmail.com/login"], ppd: getSamplePPD(id: id)))
        sampleSites.append(Site(name: "University of London", id: 3, urls: ["https://my.londoninternational.ac.uk/login"], ppd: getSamplePPD(id: id)))
        sampleSites.append(Site(name: "Github", id: 4, urls: ["https://github.com/login"], ppd: getSamplePPD(id: id)))
        sampleSites.append(Site(name: "DigitalOcean", id: 5, urls: ["https://digitalocean.com/login"], ppd: getSamplePPD(id: id)))
        sampleSites.append(Site(name: "DigitalOcean", id: 6, urls: ["https://complicatedExample.com"], ppd: getSamplePPD(id: id)))

        if id >= sampleSites.count {
            return nil
        } else {
            return sampleSites[id]
        }
    }

    private static func getSamplePPD(id: Int) -> PPD? {
        // This gets the sitID.json file and unmarshals to PPD object
        if let filepath = Bundle.main.path(forResource: String(id), ofType: "json") {
            do {
                let contents = try String(contentsOfFile: filepath)
                if let jsonData = contents.data(using: .utf8) {
                    let ppd = try JSONDecoder().decode(PPD.self, from: jsonData)
                    return ppd
                }
            } catch {
                print("PPD could not be loaded: \(error)")
            }
        } else {
            print("\(id).json not found!")
        }
        return nil
    }
}
