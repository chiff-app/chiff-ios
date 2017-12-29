//
//  AlternativeNavCon.swift
//  athena
//
//  Created by Bas Doorn on 27/12/2017.
//  Copyright © 2017 athena. All rights reserved.
//

import UIKit

class DevicesNavigationController: UINavigationController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        do {
            if try Session.all() != nil {
                let devicesViewController = storyboard?.instantiateViewController(withIdentifier: "Devices Controller")
                pushViewController(devicesViewController!, animated: false)
            } else {
                let qrViewController = storyboard?.instantiateViewController(withIdentifier: "QR Controller") as! QRViewController
                pushViewController(qrViewController, animated: false)
            }
        } catch {
            print(error)
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
