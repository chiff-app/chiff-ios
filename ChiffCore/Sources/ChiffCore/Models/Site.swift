//
//  Site.swift
//  ChiffCore
//
//  Copyright: see LICENSE.md
//

import Foundation

public struct Site: Codable {
    /// The name of the site.
    public var name: String
    /// The id of the site, which is the SHA256 hash of the URL.
    public var id: String
    /// The URL of the site.
    public var url: String
    /// If present, the PPD for this site. Saved here so we generate the same password.
    public var ppd: PPD?

    public init(name: String, id: String, url: String, ppd: PPD? = nil) {
        self.name = name
        self.id = id
        self.url = url
        self.ppd = ppd
    }
}

extension Site: Equatable {

    public static func == (lhs: Site, rhs: Site) -> Bool {
        return rhs.id == lhs.id && rhs.name == lhs.name && rhs.url == lhs.url && rhs.ppd == lhs.ppd
    }

}
