//
//  Protocols.swift
//  ChiffCore
//
//  Copyright: see LICENSE.md
//

import Foundation

public protocol AccessControllable {
    var name: String { get }
    var id: String { get }
}

public protocol PairContainerDelegate: AnyObject {
    func startLoading()
    func finishLoading()
}
