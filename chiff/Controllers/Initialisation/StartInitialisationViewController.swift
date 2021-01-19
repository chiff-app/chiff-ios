//
//  StartInitialisationViewController.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import UIKit

class StartInitialisationViewController: UIViewController {

    private let showTermsSegue = "ShowTerms"
    private let startOnboardingSegue = "StartOnboarding"

    // MARK: - Actions

    @IBAction func showTerms(_ sender: UIButton) {
        performSegue(withIdentifier: Properties.agreedWithTerms ? startOnboardingSegue : showTermsSegue, sender: self)
    }

    @IBAction func unwindAndStartOnboarding(sender: UIStoryboardSegue) {
        Properties.agreedWithTerms = true
        DispatchQueue.main.async {
            self.performSegue(withIdentifier: self.startOnboardingSegue, sender: self)
        }
    }

}
