import UIKit
import LocalAuthentication

class RequestViewController: UIViewController {

    var notification: PushNotification?
    var session: Session?
    @IBOutlet weak var siteLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        setLabel()
    }

    @IBAction func accept(_ sender: UIButton) {
        if let notification = notification, let account = try! Account.get(siteID: notification.siteID), let session = session {
            authorizeRequest(session: session, account: account, browserTab: notification.browserTab, type: notification.requestType)
        }
    }
    
    @IBAction func reject(_ sender: UIButton) {
        self.dismiss(animated: true, completion: nil)
    }
    
    func authorizeRequest(session: Session, account: Account, browserTab: Int, type: BrowserMessageType) {
        let authenticationContext = LAContext()
        var error: NSError?

        var localizedReason = ""
        switch type {
        case .login:
            localizedReason = "Login to \(account.site.name)"
        case .reset:
            localizedReason = "Reset password for \(account.site.name)"
        case .register:
             localizedReason = "Register for \(account.site.name)"
        default:
            localizedReason = "\(account.site.name)"
        }
        
        guard authenticationContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            print("Todo: handle fingerprint absence \(String(describing: error))")
            return
        }
        
        authenticationContext.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: localizedReason,
            reply: { [weak self] (success, error) -> Void in
                if (success) {
                    DispatchQueue.main.async {
                        try! session.sendCredentials(account: account, browserTab: browserTab, type: type)
                        self!.dismiss(animated: true, completion: nil)
                    }
                } else {
                    print("Todo")
                }
            }
        )
    }

    // MARK: Private functions

    private func setLabel() {
        if let id = notification?.siteID, let type = notification?.requestType {
            let site = Site.get(id: id)!
            switch type {
            case .login:
                siteLabel.text = "Login to \(site.name)?"
            case .reset:
                siteLabel.text = "Reset password for \(site.name)?"
            case .register:
                siteLabel.text = "Register for \(site.name)?"
            default:
                siteLabel.text = ""
            }
        }
    }
}
