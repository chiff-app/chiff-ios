/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit
import PromiseKit

class StartBackupViewController: UIViewController {

    var mnemonic: [String]!

    override func viewDidLoad() {
        Logger.shared.analytics(.backupExplanationOpened)
    }
    
    @IBAction func startBackup(_ sender: UIButton) {
        firstly {
            Seed.mnemonic()
        }.done(on: .main) {
            self.mnemonic = $0
            self.performSegue(withIdentifier: "StartBackup", sender: self)
        }.catch(on: .main) { error in
            self.showAlert(message: error.localizedDescription)
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "StartBackup", let destination = segue.destination.contents as? BackupWizardViewController {
            destination.mnemonic = mnemonic
        }
    }

}
