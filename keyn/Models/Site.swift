import Foundation

struct Site: Codable {

    var name: String
    var id: String
    var url: String
    var ppd: PPD?

    static func get(id: String, completion: @escaping (_ site: Site) -> Void) {
        if UserDefaults.standard.bool(forKey: "ppdTestingMode") {
            AWS.sharedInstance.getDevelopmentPPD(id: id) { (ppd) in
                completion(Site(name: ppd.name ?? "Unknown", id: id, url: ppd.url, ppd: ppd))
            }
        } else {
            AWS.sharedInstance.getPPD(id: id) { (ppd) in
                completion(Site(name: ppd.name ?? "Unknown", id: id, url: ppd.url, ppd: ppd))
            }
        }
    }

}
