//
//  noSessionsViewController.swift
//  athena
//
//  Created by bas on 08/12/2017.
//  Copyright © 2017 athena. All rights reserved.
//

import UIKit

class NoSessionsViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        guard let sessions = try? Session.all() else {
            return
        }

        if sessions != nil, sessions!.isEmpty {
            dismiss(animated: true, completion: nil)
            return
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
    @IBAction func addSession(_ sender: UIButton) {
        self.parent?.tabBarController?.selectedIndex = 1
    }

}
