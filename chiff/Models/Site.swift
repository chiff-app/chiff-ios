//
//  Site.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import Foundation

struct Site: Codable {
    var name: String
    var id: String
    var url: String
    var ppd: PPD?
}

extension Site: Equatable {

    static func == (lhs: Site, rhs: Site) -> Bool {
        return rhs.id == lhs.id && rhs.name == lhs.name && rhs.url == lhs.url && rhs.ppd == lhs.ppd
    }

}
