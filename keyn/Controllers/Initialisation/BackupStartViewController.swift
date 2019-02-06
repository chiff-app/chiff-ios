/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit
import JustLog

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
        let storyboard: UIStoryboard = UIStoryboard(name: "Initialisation", bundle: nil)
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
                try BackupManager.sharedInstance.initialize()
                Logger.shared.info("Seed created", userInfo: ["code": AnalyticsMessage.seedCreated.rawValue])
            } catch {
                Logger.shared.error("Error generating seed.", error: error as NSError)
            }
        }
    }
}
