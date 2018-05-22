import Foundation

/*
 * A site can have multiple URLs (e.g. live.com and hotmail.com).
 */
struct Site: Codable {

    var name: String
    var id: String
    var urls: [String]
    var ppd: PPD?

    static func get(id: String, completion: @escaping (_ site: Site) -> Void) {
        if UserDefaults.standard.bool(forKey: "ppdTestingMode") {
            AWS.sharedInstance.getDevelopmentPPD(id: id) { (ppd) in
                var urls = [String]()
                urls.append(ppd.url)
                completion(Site(name: ppd.name ?? "Unknown", id: id, urls: urls, ppd: ppd))
            }
        } else {
            AWS.sharedInstance.getPPD(id: 0) { (ppd) in
                var urls = [String]()
                urls.append(ppd.url)
                completion(Site(name: ppd.name ?? "Unknown", id: id, urls: urls, ppd: ppd))
            }
        }
    }

}
