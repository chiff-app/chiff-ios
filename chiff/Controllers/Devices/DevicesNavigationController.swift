//
//  DevicesNavigationController.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import UIKit
import ChiffCore

class DevicesNavigationController: UINavigationController {
    override func viewDidLoad() {
        super.viewDidLoad()
        do {
            if try !BrowserSession.all().isEmpty {
                let devicesViewController = storyboard?.instantiateViewController(withIdentifier: "Devices Controller")
                pushViewController(devicesViewController!, animated: false)
            } else if let pairViewController = storyboard?.instantiateViewController(withIdentifier: "Pair Controller") as? PairViewController {
                pushViewController(pairViewController, animated: false)
            }
        } catch {
            Logger.shared.error("Could not get sessions.", error: error)
        }
    }
}
