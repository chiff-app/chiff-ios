//
//  ASCredentialServiceIdentifier+Site.swift
//  chiffCredentialProvider
//
//  Copyright: see LICENSE.md
//

import Foundation
import AuthenticationServices
import ChiffCore

extension ASCredentialServiceIdentifier {

    var site: Site? {
        switch self.type {
        case .URL:
            guard let url = URL(string: identifier) else {
                return nil
            }
            guard let host = url.host else {
                return nil
            }
            let name = host.starts(with: "www.") ? String(host.dropFirst(4)) : host
            guard let scheme = url.scheme else {
                return nil
            }
            let urlString = "\(scheme)://\(host)"
            return Site(name: name, id: urlString.lowercased().sha256, url: urlString, ppd: nil)
        case .domain:
            let name = identifier.starts(with: "www.") ? String(identifier.dropFirst(4)) : identifier
            let url = "https://\(identifier)"
            return Site(name: name, id: url.lowercased().sha256, url: url, ppd: nil)
        @unknown default:
            return nil
        }
    }

}
