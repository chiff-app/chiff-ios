//
//  BaseAccount.swift
//  keyn
//
//  Created by Bas Doorn on 17/03/2020.
//  Copyright © 2020 keyn. All rights reserved.
//

import Foundation

/// Shared properties for accounts
protocol BaseAccount: Codable {
    var id: String { get }
    var username: String { get set }
    var sites: [Site] { get set }
    var site: Site { get }
    var passwordIndex: Int { get set }
    var passwordOffset: [Int]? { get set }
    var version: Int { get }
    var hasPassword: Bool { get }
    var notes: String? { get set }
}

extension BaseAccount {

    var site: Site {
        return sites.first!
    }

    var hasPassword: Bool {
        return passwordIndex >= 0
    }

}
