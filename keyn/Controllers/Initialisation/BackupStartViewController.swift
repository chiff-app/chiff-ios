/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit

class BackupStartViewController: UIViewController {
    var isInitialSetup = true

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
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
                try BackupManager.shared.initialize(completion: { (result) in
                    // TODO: Only continue if result = true.
                })
                Logger.shared.analytics("Seed created", code: .seedCreated)
            } catch {
                Logger.shared.error("Error generating seed.", error: error)
            }
        }
    }
}
