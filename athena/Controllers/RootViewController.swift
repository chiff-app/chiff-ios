//
//  RootViewController.swift
//  athena
//
//  Created by bas on 03/11/2017.
//  Copyright © 2017 athena. All rights reserved.
//

import UIKit

class RootViewController: UITabBarController {
    
    var isFirstLaunch = false

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if isFirstLaunch {
            let seedStoryboard: UIStoryboard = UIStoryboard(name: "Backup", bundle: nil)
            let seedRootViewController = seedStoryboard.instantiateViewController(withIdentifier: "RootController")
            seedRootViewController.modalPresentationStyle = .fullScreen
            self.present(seedRootViewController, animated: true, completion: nil)
            isFirstLaunch = false
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

}
