//
//  SeedGenerationViewController.swift
//  keyn
//
//  Created by Bas Doorn on 09/12/2017.
//  Copyright © 2017 keyn. All rights reserved.
//

import UIKit

class BackupWizardViewController: UIViewController {

    @IBOutlet weak var wordLabel: UILabel!
    @IBOutlet weak var previousButton: UIButton!
    var mnemonic: [String]?
    var counter: Int = 0
    @IBOutlet weak var counterLabel: UILabel!
    var isInitialSetup = true

    override func viewDidLoad() {
        super.viewDidLoad()
        do {
            mnemonic = try Seed.mnemonic()
            wordLabel.text = mnemonic![counter]
            counterLabel.text = "Word \(counter + 1) of \(mnemonic!.count)"
        } catch {
            // Handle error and total destruction
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: Actions
    @IBAction func next(_ sender: UIButton) {
        if counter < mnemonic!.count - 1 {
            counter += 1
            wordLabel.text = mnemonic![counter]
            counterLabel.text = "word \(counter + 1) of \(mnemonic!.count)"
            if (counter >= 1) {
                previousButton.isEnabled = true
            }
        } else {
            let checkViewController = storyboard?.instantiateViewController(withIdentifier: "Mnemonic Check") as! BackupCheckViewController
            checkViewController.mnemonic = mnemonic
            checkViewController.isInitialSetup = isInitialSetup
            navigationController?.pushViewController(checkViewController, animated: true)
        }
    }

    @IBAction func previous(_ sender: UIButton) {
        if counter > 0 {
            counter -= 1
            wordLabel.text = mnemonic![counter]
            counterLabel.text = "word \(counter + 1) of \(mnemonic!.count)"
            if (counter <= 0) {
                previousButton.isEnabled = false
            }
        }
    }

    @IBAction func cancel(_ sender: UIBarButtonItem) {
        if isInitialSetup {
            let storyboard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
            let rootController = storyboard.instantiateViewController(withIdentifier: "RootController") as! RootViewController
            UIApplication.shared.keyWindow?.rootViewController = rootController
        } else {
            dismiss(animated: true, completion: nil)
        }
    }

}
