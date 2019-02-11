/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit

class BackupWizardViewController: UIViewController {
    @IBOutlet weak var wordLabel: UILabel!
    @IBOutlet weak var previousButton: UIButton!
    @IBOutlet weak var counterLabel: UILabel!
    
    var mnemonic: [String]?
    var counter: Int = 0
    var isInitialSetup = true

    override func viewDidLoad() {
        super.viewDidLoad()
        do {
            mnemonic = try Seed.mnemonic()
            wordLabel.text = mnemonic![counter]
            counterLabel.text = "Word \(counter + 1) of \(mnemonic!.count)"
        } catch {
            Logger.shared.error("Error getting mnemonic.", error: error)
        }
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return UIStatusBarStyle.lightContent
    }
    
    // MARK: - Actions

    @IBAction func next(_ sender: UIButton) {
        if counter < mnemonic!.count - 1 {
            counter += 1
            wordLabel.text = mnemonic![counter]
            counterLabel.text = "word \(counter + 1) of \(mnemonic!.count)"
            if (counter >= 1) {
                previousButton.isEnabled = true
                previousButton.alpha = 1.0
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
                previousButton.alpha = 0.5
            }
        }
    }

    @IBAction func cancel(_ sender: UIBarButtonItem) {
        let alert = UIAlertController(title: "Cancel backup?", message: "You can complete the backup sequence later.", preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Continue", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Cancel", style: .destructive, handler: { action in
            if self.isInitialSetup {
                let storyboard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
                let rootController = storyboard.instantiateViewController(withIdentifier: "RootController") as! RootViewController
                rootController.selectedIndex = 1
                UIApplication.shared.keyWindow?.rootViewController = rootController
            } else {
                self.dismiss(animated: true, completion: nil)
            }
        }))
        self.present(alert, animated: true, completion: nil)
    }
}
