//
//  SeedGenerationViewController.swift
//  athena
//
//  Created by Bas Doorn on 09/12/2017.
//  Copyright © 2017 athena. All rights reserved.
//

import UIKit

class BackupWizardViewController: UIViewController {

    @IBOutlet weak var wordLabel: UILabel!
    @IBOutlet weak var previousButton: UIButton!
    var mnemonic: [String]?
    var counter: Int = 0
    @IBOutlet weak var counterLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        do {
            mnemonic = try Seed.mnemonic()
            wordLabel.text = mnemonic![counter]
            counterLabel.text = "Word \(counter + 1) of \(mnemonic!.count)"
        } catch {
            // Handle error and total destruction
        }
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
    @IBAction func next(_ sender: Any) {
        if counter < mnemonic!.count - 1 {
            counter += 1
            wordLabel.text = mnemonic![counter]
            counterLabel.text = "word \(counter + 1) of \(mnemonic!.count)"
            if (counter >= 1) {
                previousButton.isEnabled = true
            }
        } else {
            let checkViewController = storyboard?.instantiateViewController(withIdentifier: "Mnemonic Check") as! BackupCheckViewController
            checkViewController.mnemonic = mnemonic
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
            }
        }
    }

    @IBAction func cancel(_ sender: UIBarButtonItem) {
        let storyboard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
        let rootController = storyboard.instantiateViewController(withIdentifier: "RootController") as! RootViewController
        UIApplication.shared.keyWindow?.rootViewController = rootController
    }

}
