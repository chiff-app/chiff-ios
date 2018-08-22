//
//  AuthenticationViewController.swift
//  keyn
//
//  Created by bas on 02/02/2018.
//  Copyright © 2018 keyn. All rights reserved.
//

import UIKit

class AuthenticationViewController: UIViewController {

    @IBOutlet var passcodeButtons: [UIButton]!
    @IBOutlet weak var deleteButton: UIButton!
    @IBOutlet weak var touchIDButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        drawButtons()

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

    @IBAction func touchID(_ sender: UIButton) {
        AuthenticationGuard.sharedInstance.authenticateUser(cancelChecks: false)
    }

    // MARK: Private methods

    private func drawButtons() {
        touchIDButton.imageView!.contentMode = .scaleAspectFit
        touchIDButton.imageEdgeInsets = UIEdgeInsetsMake(13, 13, 13, 13)

        for button in passcodeButtons {
            button.layer.borderWidth = 1.3
            button.layer.borderColor = UIColor.white.cgColor
            button.layer.cornerRadius = button.frame.width/2
        }
    }

}
