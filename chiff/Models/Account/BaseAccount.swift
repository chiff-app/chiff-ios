//
//  BaseAccount.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import Foundation

/// Contains the shared properties for accounts
protocol BaseAccount: Codable {
    var id: String { get }
    var username: String { get set }
    var sites: [Site] { get set }
    var site: Site { get }
    var passwordIndex: Int { get set }
    var passwordOffset: [Int]? { get set }
    var version: Int { get }
    var hasPassword: Bool { get }
}

extension BaseAccount {

    var site: Site {
        return sites.first!
    }

    var hasPassword: Bool {
        return passwordIndex >= 0
    }

}
