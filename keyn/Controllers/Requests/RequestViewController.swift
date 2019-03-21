/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit
import LocalAuthentication

class RequestViewController: UIViewController {

    @IBOutlet weak var requestLabel: UILabel!
    @IBOutlet weak var successView: UIStackView!
    @IBOutlet weak var successTextLabel: UILabel!
    @IBOutlet weak var successTextDetailLabel: UILabel!

    var authorizationGuard: AuthorizationGuard!

    private var accounts = [Account]()

    override func viewDidLoad() {
        super.viewDidLoad()
        switch authorizationGuard.type {
        case .login:
            requestLabel.text = "Confirm login"
        case .add:
            requestLabel.text = "Add account"
        case .change:
            requestLabel.text = "Change password"
        case .fill:
            requestLabel.text = "Fill password"
        default:
            requestLabel.text = "Unknown request"
        }
        try? authorizationGuard.acceptRequest {
            DispatchQueue.main.async {
                self.success()
            }
        }
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return UIStatusBarStyle.lightContent
    }

    // MARK: - Private functions

    private func success() {
        switch authorizationGuard.type {
            case .login:
                successTextLabel.text = "Login successful"
                successTextDetailLabel.text = "Return to your computer"
            case .add:
                successTextLabel.text = "Account added"
                successTextDetailLabel.text = "Next time you can login with Keyn"
            case .change:
                successTextLabel.text = "New password generated"
                successTextDetailLabel.text = "Return to your computer to complete the process"
            case .fill:
                successTextLabel.text = "Fill password successful"
                successTextDetailLabel.text = "Return to your computer"
            default:
            requestLabel.text = "Unknown request"
        }
        self.successView.alpha = 0.0
        self.successView.isHidden = false
        UIView.animate(withDuration: 0.3, delay: 0.0, options: [.curveLinear], animations: { self.successView.alpha = 1.0 })
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            self.dismiss(animated: true, completion: nil)
        }
    }

    // MARK: - Actions

    @IBAction func authenticate(_ sender: UIButton) {
        do {
            try authorizationGuard.acceptRequest {
                DispatchQueue.main.async {
                    self.success()
                }
            }
        } catch {
            #warning("TODO: SHow error")
        }
    }

    @IBAction func close(_ sender: UIButton) {
        authorizationGuard.rejectRequest() {
            DispatchQueue.main.async {
                self.dismiss(animated: true, completion: nil)
            }
        }
    }
}
