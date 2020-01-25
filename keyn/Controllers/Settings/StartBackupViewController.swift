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
    
    @IBAction func startBackup(_ sender: UIButton) {
        Seed.mnemonic { (result) in
            DispatchQueue.main.async {
                switch result {
                case .success(let mnemonic):
                    self.mnemonic = mnemonic
                    self.performSegue(withIdentifier: "StartBackup", sender: self)
                case .failure(let error):
                    self.showAlert(message: error.localizedDescription)
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
