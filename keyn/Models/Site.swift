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
}
