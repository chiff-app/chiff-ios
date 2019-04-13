//
//  PairContainerViewController.swift
//  keyn
//
//  Created by Bas Doorn on 25/03/2019.
//  Copyright © 2019 keyn. All rights reserved.
//

import UIKit

class PairContainerViewController: UIViewController {

    var pairControllerDelegate: PairControllerDelegate!

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let identifier = segue.identifier, identifier == "EmbeddedPairing", let destination = segue.destination as? PairViewController {
            destination.pairControllerDelegate = pairControllerDelegate
        }
    }

}
