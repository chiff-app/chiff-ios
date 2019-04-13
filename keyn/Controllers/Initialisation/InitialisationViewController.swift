/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit

class InitialisationViewController: UIViewController {

    override func viewDidLoad() {
        if let navController = navigationController {
            System.clearNavigationBar(forBar: navController.navigationBar)
            navController.view.backgroundColor = .clear
        }
    }
    
}
