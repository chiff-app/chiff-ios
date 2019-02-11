/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit

class DevicesNavigationController: UINavigationController {
    override func viewDidLoad() {
        super.viewDidLoad()
        do {
            if try Session.all() != nil {
                let devicesViewController = storyboard?.instantiateViewController(withIdentifier: "Devices Controller")
                pushViewController(devicesViewController!, animated: false)
            } else {
                let pairViewController = storyboard?.instantiateViewController(withIdentifier: "Pair Controller") as! PairViewController
                pushViewController(pairViewController, animated: false)
            }
        } catch {
            Logger.shared.error("Could not get sessions.", error: error)
        }
    }
}
