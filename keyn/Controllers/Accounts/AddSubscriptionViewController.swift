//
//  AddSubscriptionViewController.swift
//  keyn
//
//  Created by Bas Doorn on 24/07/2019.
//  Copyright © 2019 keyn. All rights reserved.
//

import UIKit

class AddSubscriptionViewController: UIViewController {

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let destination = segue.destination.contents as? SubscriptionViewController {
            destination.presentedModally = true
        }
    }

}
