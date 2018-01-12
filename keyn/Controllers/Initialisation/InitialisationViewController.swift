//
//  InitialisationViewController.swift
//  keyn
//
//  Created by bas on 22/12/2017.
//  Copyright © 2017 keyn. All rights reserved.
//

import UIKit

class InitialisationViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

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

    @IBAction func generateSeed(_ sender: UIButton) {
        do {
            try Seed.create()
        } catch {
            print("TODO: Present error when seed can't be created.")
            print(error)
        }
    }
    
}
