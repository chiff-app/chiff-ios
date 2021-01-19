//
//  PairContainerViewController.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import UIKit

class PairContainerViewController: UIViewController, PairContainerDelegate {

    weak var pairControllerDelegate: PairControllerDelegate!
    @IBOutlet weak var activityView: UIView!

    override func viewDidLoad() {
        super.viewDidLoad()
        reEnableBarButtonFont()
    }

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
