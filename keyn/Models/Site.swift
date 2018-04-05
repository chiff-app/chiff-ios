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
        guard let ppd = getSamplePPD(id: id) else {
            return nil
        }
        let name = ppd.name ?? "Unknown"
        var urls = [String]()
        urls.append(ppd.url)

        return Site(name: name, id: id, urls: urls, ppd: ppd)
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
