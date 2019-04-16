//
//  StartBackupViewController.swift
//  keyn
//
//  Created by Bas Doorn on 16/04/2019.
//  Copyright © 2019 keyn. All rights reserved.
//

import UIKit

class StartBackupViewController: UIViewController {

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        (tabBarController as? RootViewController)?.showGradient(false)
    }

}
