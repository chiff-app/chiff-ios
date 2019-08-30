/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit

class StartBackupViewController: UIViewController {

    var mnemonic: [String]!

    override func viewDidLoad() {
        Logger.shared.analytics(.backupExplanationOpened)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        (tabBarController as? RootViewController)?.showGradient(false)
    }

    
    @IBAction func startBackup(_ sender: UIButton) {
        Seed.mnemonic { (mnemonic, error) in
            DispatchQueue.main.async {
                if let error = error {
                    self.showError(message: error.localizedDescription)
                } else {
                    self.mnemonic = mnemonic
                    self.performSegue(withIdentifier: "StartBackup", sender: self)
                }
            }
        }

    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "StartBackup", let destination = segue.destination.contents as? BackupWizardViewController {
            destination.mnemonic = mnemonic
        }
    }

}
