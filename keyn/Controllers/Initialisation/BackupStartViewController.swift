/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit

class BackupStartViewController: UIViewController {

    var isInitialSetup = true

    override func viewDidLoad() {
        super.viewDidLoad()

        if !isInitialSetup {
            navigationItem.largeTitleDisplayMode = .never
        }
    }

    // MARK: - Actions

    @IBAction func startBackupWizard(_ sender: UIButton) {
        let storyboard: UIStoryboard = UIStoryboard.get(.initialisation)
        if isInitialSetup {
            let viewController = storyboard.instantiateViewController(withIdentifier: "Backup Wizard")
            navigationController?.pushViewController(viewController, animated: true)
        } else {
            let viewController = storyboard.instantiateViewController(withIdentifier: "Wizard Navigator")
            if let content = viewController.contents as? BackupWizardViewController {
                content.isInitialSetup = false
            }
            self.modalPresentationStyle = .fullScreen
            self.present(viewController, animated: true, completion: nil)
        }
    }
    
    @IBAction func generateSeed(_ sender: UIButton) {
        if isInitialSetup {
            do {
                try Seed.create()
                try BackupManager.shared.initialize() { (result) in
                    #warning("TODO: When the creation failed (e.g. result != true) we should not continue backup process and inform the user.")
                }
                Logger.shared.analytics("Seed created", code: .seedCreated)
            } catch {
                Logger.shared.error("Error generating seed.", error: error)
            }
        }
    }

}
