//
//  RequestViewController.swift
//  keyn
//
//  Created by bas on 19/01/2018.
//  Copyright © 2018 keyn. All rights reserved.
//

import UIKit

class RequestViewController: UIViewController {

    var session: Session?

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
    @IBAction func tempAction(_ sender: UIButton) {
        if session != nil { print(session!.id) }
        self.dismiss(animated: true, completion: nil)
    }

}
