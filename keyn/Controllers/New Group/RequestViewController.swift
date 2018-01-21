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
    var sandboxed = false
    var accepted = false

    override func viewDidLoad() {
        super.viewDidLoad()
        if accepted {
            if let id = siteID, let account = try! Account.get(siteID: id), let session = session {
                authenticateUser(session: session, account: account, sandboxed: sandboxed)
            }
        }
    }

    @IBAction func accept(_ sender: UIButton) {
        if let id = siteID, let account = try! Account.get(siteID: id), let session = session {
            authenticateUser(session: session, account: account, sandboxed: sandboxed)
        }
    }
    
    @IBAction func reject(_ sender: UIButton) {
        if sandboxed {
            // What should happen here?
        } else {
            self.dismiss(animated: true, completion: nil)
        }
    }
    
    func authenticateUser(session: Session, account: Account, sandboxed: Bool) {
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
                        try! session.sendPassword(account: account)
                        if !sandboxed {
                            self!.dismiss(animated: true, completion: nil)
                        } else {
                            if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
                                appDelegate.authenticated = true
                            }
                            let storyboard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
                            let viewController = storyboard.instantiateViewController(withIdentifier: "RootController") as! RootViewController
                            UIApplication.shared.keyWindow?.rootViewController = viewController
                        }
                    }
                } else {
                    print("Todo")
                }
            }
        )
    }

    
}
