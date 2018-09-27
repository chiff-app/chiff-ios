import Foundation

struct Site: Codable {

    var name: String
    var id: String
    var url: String
    var ppd: PPD?

    static func get(id: String, completion: @escaping (_ site: Site?) -> Void) throws {
        try PPD.get(id: id) { (ppd) in
            guard let ppd = ppd else {
                completion(nil)
                return
            }
            completion(Site(name: ppd.name, id: id, url: ppd.url, ppd: ppd))
        }
    }

}
