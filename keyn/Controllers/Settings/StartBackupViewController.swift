/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit

class StartBackupViewController: UIViewController {

    override func viewDidLoad() {
        Logger.shared.analytics(.backupExplanationOpened)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        (tabBarController as? RootViewController)?.showGradient(false)
    }

}
