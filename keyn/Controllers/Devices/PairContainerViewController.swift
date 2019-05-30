//
//  PairContainerViewController.swift
//  keyn
//
//  Created by Bas Doorn on 25/03/2019.
//  Copyright © 2019 keyn. All rights reserved.
//

import UIKit

class PairContainerViewController: UIViewController, PairContainerDelegate {

    var pairControllerDelegate: PairControllerDelegate!
    @IBOutlet weak var activityView: UIView!

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let identifier = segue.identifier, identifier == "EmbeddedPairing", let destination = segue.destination as? PairViewController {
            destination.pairControllerDelegate = pairControllerDelegate
            destination.pairContainerDelegate = self
        }
    }

    func startLoading() {
        DispatchQueue.main.async {
            self.activityView.isHidden = false
        }
    }

    func finishLoading() {
        DispatchQueue.main.async {
            self.activityView.isHidden = true
        }
    }

}
