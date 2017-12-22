//
//  SeedGenerationViewController.swift
//  athena
//
//  Created by Bas Doorn on 09/12/2017.
//  Copyright © 2017 athena. All rights reserved.
//

import UIKit

class BackupWizardViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        try! Seed.mnemonic()

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */
    
    // MARK: Actions
    @IBAction func cancel(_ sender: UIButton) {
        let storyboard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
        let rootController = storyboard.instantiateViewController(withIdentifier: "RootController") as! RootViewController
        UIApplication.shared.keyWindow?.rootViewController = rootController
    }
    
}
