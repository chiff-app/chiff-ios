/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import Foundation

struct Site: Codable {

    var name: String
    var id: String
    var url: String
    var ppd: PPD?

    static func get(id: String, completionHandler: @escaping (_ site: Site?) -> Void) throws {
        try PPD.get(id: id) { (ppd) in
            guard let ppd = ppd else {
                completionHandler(nil)
                return
            }

            completionHandler(Site(name: ppd.name, id: id, url: ppd.url, ppd: ppd))
        }
    }
    
}
