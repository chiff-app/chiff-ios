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
    var counter: Int = 0 {
        didSet {
            counterLabel.text = "\("word".localized.capitalized) \(counter + 1) of \(mnemonic!.count)"
        }
    }
    var isInitialSetup = true

    override func viewDidLoad() {
        super.viewDidLoad()
        do {
            mnemonic = try Seed.mnemonic()
            wordLabel.text = mnemonic![counter]
            counterLabel.text = "\("word".localized.capitalized) \(counter + 1) of \(mnemonic!.count)"
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
            if (counter <= 0) {
                previousButton.isEnabled = false
                previousButton.alpha = 0.5
            }
        }
    }

    @IBAction func cancel(_ sender: UIBarButtonItem) {
        let alert = UIAlertController(title: "\("cancel_backup".localized.capitalized)", message: "cancel_backup_description".localized, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "continue".localized.capitalized, style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "cancel".localized.capitalized, style: .destructive, handler: { action in
            if self.isInitialSetup {
                let rootController = UIStoryboard.main.instantiateViewController(withIdentifier: "RootController") as! RootViewController
                rootController.selectedIndex = 1
                UIApplication.shared.keyWindow?.rootViewController = rootController
            } else {
                self.dismiss(animated: true, completion: nil)
            }
        }))
        self.present(alert, animated: true, completion: nil)
    }
}
