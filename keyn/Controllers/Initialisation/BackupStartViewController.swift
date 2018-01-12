//
//  BackupStartViewController.swift
//  keyn
//
//  Created by bas on 02/01/2018.
//  Copyright © 2018 keyn. All rights reserved.
//

import UIKit

class BackupStartViewController: UIViewController {

    var isInitialSetup = true

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
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

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
