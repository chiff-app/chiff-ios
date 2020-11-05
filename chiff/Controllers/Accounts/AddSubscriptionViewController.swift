//
//  AddSubscriptionViewController.swift
//  chiff
//
//  Copyright: see LICENSE.md
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
