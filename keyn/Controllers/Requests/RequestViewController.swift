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
            case .add:
                Site.get(id: notification.siteID, completion: { (site) in
                    self.site = site
                    self.performSegue(withIdentifier: "RegistrationRequestSegue", sender: self)
                })
            case .login, .change:
                if account == nil {
                    Site.get(id: notification.siteID, completion: { (site) in
                        self.site = site
                        self.performSegue(withIdentifier: "RegistrationRequestSegue", sender: self)
                    })
                } else {
                    authorize(notification: notification, session: session)
                }
            case .register:
                print("TODO: Fix register requests")
            default:
                print("Unknown requestType")
            }
        }
    }
    
    @IBAction func reject(_ sender: UIButton) {
        self.dismiss(animated: true, completion: nil)
    }
    
    // MARK: Private functions
    
    private func authorize(notification: PushNotification, session: Session) {
        // TODO: Handle error throwing here
        AuthenticationGuard.sharedInstance.authorizeRequest(siteName: notification.siteName, type: notification.requestType, completion: { [weak self] (succes, error) in
            if (succes) {
                DispatchQueue.main.async {
                    var account = try! Account.get(siteID: notification.siteID)
                    var oldPassword: String?
                    if notification.requestType == .change {
                        oldPassword = try! account!.password()
                        try! account!.updatePassword(offset: nil)
                    }
                    try! session.sendCredentials(account: account!, browserTab: notification.browserTab, type: notification.requestType, password: oldPassword)
                    self!.dismiss(animated: true, completion: nil)
                }
            } else {
                print("TODO: Handle touchID errors.")
            }
        })
    }

    private func analyseRequest() {
        if let notification = notification, let session = session {
            siteLabel.text = notification.siteName
            // TODO: Crash app for now.
            do {
                account = try! Account.get(siteID: notification.siteID)
                setLabel(requestType: notification.requestType)
                if account != nil && (notification.requestType == .login || notification.requestType == .change) {
                    // Automatically present the touchID popup
                    authorize(notification: notification, session: session)
                }
            } catch {
                print("Error getting account: \(error)")
            }
        }
    }

    private func setLabel(requestType: BrowserMessageType) {
        switch requestType {
        case .login:
            siteLabel.text = self.account != nil ? "Login to \(notification!.siteName)?" : "Add \(notification!.siteName)?"
        case .change:
            siteLabel.text = self.account != nil ? "Change password for \(notification!.siteName)?" : "Add \(notification!.siteName)?"
        case .reset:
            siteLabel.text = "Reset password for \(notification!.siteName)?"
        case .register:
            siteLabel.text = "Register for \(notification!.siteName)?"
        case .add:
            siteLabel.text = "Add \(notification!.siteName)?"
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



