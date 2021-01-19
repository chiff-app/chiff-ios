//
//  Site.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import Foundation

struct Site: Codable {
    /// The name of the site.
    var name: String
    /// The id of the site, which is the SHA256 hash of the URL.
    var id: String
    /// The URL of the site.
    var url: String
    /// If present, the PPD for this site. Saved here so we generate the same password.
    var ppd: PPD?
}

extension Site: Equatable {

    static func == (lhs: Site, rhs: Site) -> Bool {
        return rhs.id == lhs.id && rhs.name == lhs.name && rhs.url == lhs.url && rhs.ppd == lhs.ppd
    }

}
