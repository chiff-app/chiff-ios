import UIKit
import LocalAuthentication

class RequestViewController: UIViewController {

    var notification: PushNotification?
    var session: Session?
    var account: Account?
    var site: Site?
    @IBOutlet weak var siteLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        analyseRequest()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return UIStatusBarStyle.lightContent
    }

    @IBAction func accept(_ sender: UIButton) {
        if let notification = notification, let session = session {
            switch notification.requestType {
            case .login, .change:
                if let account = self.account {
                    authorizeRequest(site: account.site, type: notification.requestType, completion: { [weak self] (succes, error) in
                        if (succes) {
                            DispatchQueue.main.async {
                                try! session.sendCredentials(account: account, browserTab: notification.browserTab, type: notification.requestType)
                                self!.dismiss(animated: true, completion: nil)
                            }
                        } else {
                            print("TODO: Handle touchID errors.")
                        }
                    })
                } else {
                    self.performSegue(withIdentifier: "RegistrationRequestSegue", sender: self)
                }
            case .register:
                self.performSegue(withIdentifier: "RegistrationRequestSegue", sender: self)
            default:
                print("Unknown requestType")
            }
        }
    }
    
    @IBAction func reject(_ sender: UIButton) {
        self.dismiss(animated: true, completion: nil)
    }
    
    // MARK: Private functions

    private func analyseRequest() {
        if let notification = notification, let session = session {
            site = Site.get(id: notification.siteID)
            guard site != nil else {
                siteLabel.text = "Unknown site"
                return
            }
            // TODO: Crash app for now.
            do {
                account = try! Account.get(siteID: notification.siteID)
                setLabel(requestType: notification.requestType)
                if let account = self.account {
                    // Automatically present the touchID popup
                    //session: Session, account: Account, browserTab: Int, type: BrowserMessageType,
                    authorizeRequest(site: site!, type: notification.requestType, completion: { [weak self] (succes, error) in
                        if (succes) {
                            DispatchQueue.main.async {
                                try! session.sendCredentials(account: account, browserTab: notification.browserTab, type: notification.requestType)
                                self!.dismiss(animated: true, completion: nil)
                            }
                        } else {
                            print("TODO: Handle touchID errors.")
                        }
                    })
                }
            } catch {
                print("Error getting account: \(error)")
            }
        }
    }

    private func setLabel(requestType: BrowserMessageType) {
        switch requestType {
        case .login:
            siteLabel.text = self.account != nil ? "Login to \(site!.name)?" : "Add \(site!.name)?"
        case .change:
            siteLabel.text = self.account != nil ? "Change password for \(site!.name)?" : "Add \(site!.name)?"
        case .reset:
            siteLabel.text = "Reset password for \(site!.name)?"
        case .register:
            siteLabel.text = "Register for \(site!.name)?"
        default:
            siteLabel.text = "Request error :("
        }
    }


    // MARK: - Navigation

    @IBAction func unwindToRequestViewController(sender: UIStoryboardSegue) {
        self.dismiss(animated: false, completion: nil)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        if segue.identifier == "RegistrationRequestSegue" {
            if let destinationController = (segue.destination.contents) as? RegistrationRequestViewController {
                destinationController.site = site
                destinationController.session = session
                destinationController.notification = notification
            }
        }
    }
}


