//
//  AlternativeNavCon.swift
//  keyn
//
//  Created by Bas Doorn on 27/12/2017.
//  Copyright © 2017 keyn. All rights reserved.
//

import UIKit
import JustLog

class DevicesNavigationController: UINavigationController {

    override func viewDidLoad() {
        super.viewDidLoad()
        do {
            if try Session.all() != nil {
                let devicesViewController = storyboard?.instantiateViewController(withIdentifier: "Devices Controller")
                pushViewController(devicesViewController!, animated: false)
            } else {
                let pairViewController = storyboard?.instantiateViewController(withIdentifier: "Pair Controller") as! PairViewController
                pushViewController(pairViewController, animated: false)
            }
        } catch {
            Logger.shared.error("Could not get sessions.", error: error as NSError)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

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

}
