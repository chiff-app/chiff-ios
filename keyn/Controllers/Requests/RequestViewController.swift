//
//  RequestViewController.swift
//  keyn
//
//  Created by bas on 19/01/2018.
//  Copyright © 2018 keyn. All rights reserved.
//

import UIKit
import LocalAuthentication

class RequestViewController: UIViewController {

    var session: Session?
    var siteID: String?
    var browserTab: Int? // Is this a good location?

    @IBOutlet weak var siteLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        if let id = siteID {
            let site = Site.get(id: id)
            siteLabel.text = "Login to \(site?.name)?"
        }
    }

    @IBAction func accept(_ sender: UIButton) {
        if let id = siteID, let account = try! Account.get(siteID: id), let session = session, let browserTab = browserTab {
            authenticateUser(session: session, account: account, browserTab: browserTab)
        }
    }
    
    @IBAction func reject(_ sender: UIButton) {
        self.dismiss(animated: true, completion: nil)
    }
    
    func authenticateUser(session: Session, account: Account, browserTab: Int) {
        let authenticationContext = LAContext()
        var error: NSError?
        
        guard authenticationContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            print("Todo: handle fingerprint absence \(String(describing: error))")
            return
        }
        
        authenticationContext.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: "Login to \(account.site.name)",
            reply: { [weak self] (success, error) -> Void in
                if (success) {
                    DispatchQueue.main.async {
                        try! session.sendCredentials(account: account, browserTab: browserTab)
                        self!.dismiss(animated: true, completion: nil)
                    }
                } else {
                    print("Todo")
                }
            }
        )
    }

}
