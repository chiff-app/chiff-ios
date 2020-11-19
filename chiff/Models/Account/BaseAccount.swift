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

    /// Get the first site from the sites array.
    var site: Site {
        return sites.first!
    }

    /// Whether this account has a password.
    var hasPassword: Bool {
        return passwordIndex >= 0
    }

}
