//
//  StartInitialisationViewController.swift
//  keyn
//
//  Created by Bas Doorn on 05/12/2019.
//  Copyright © 2019 keyn. All rights reserved.
//

import UIKit

class StartInitialisationViewController: UIViewController {

    private let showTermsSegue = "ShowTerms"
    private let startOnboardingSegue = "StartOnboarding"

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
