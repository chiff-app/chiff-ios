import Foundation

struct Site: Codable {

    var name: String
    var id: String
    var url: String
    var ppd: PPD?

    static func get(id: String, completion: @escaping (_ site: Site) -> Void) {
        PPD.get(id: id) { (ppd) in
            completion(Site(name: ppd.name ?? "Unknown", id: id, url: ppd.url, ppd: ppd))
        }
    }

}
