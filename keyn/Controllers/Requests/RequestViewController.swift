import UIKit
import LocalAuthentication

class RequestViewController: UIViewController {

    var notification: PushNotification?
    var session: Session?
    @IBOutlet weak var siteLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()

        if let id = notification?.siteID {
            let site = Site.get(id: id)!
            siteLabel.text = "Login to \(site.name)?"
        }
    }

    @IBAction func accept(_ sender: UIButton) {
        if let notification = notification, let account = try! Account.get(siteID: notification.siteID), let session = session {
            authorizeRequest(session: session, account: account, browserTab: notification.browserTab, type: notification.requestType)
        }
    }
    
    @IBAction func reject(_ sender: UIButton) {
        self.dismiss(animated: true, completion: nil)
    }
    
    func authorizeRequest(session: Session, account: Account, browserTab: Int, type: RequestType) {
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
                        try! session.sendCredentials(account: account, browserTab: browserTab, type: type)
                        self!.dismiss(animated: true, completion: nil)
                    }
                } else {
                    print("Todo")
                }
            }
        )
    }

}
