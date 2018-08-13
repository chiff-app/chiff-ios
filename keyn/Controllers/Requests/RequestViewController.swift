import UIKit
import LocalAuthentication
import JustLog

class RequestViewController: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource {

    var notification: PushNotification?
    var session: Session?
    var accounts = [Account]()
    var site: Site?
    let PICKER_HEIGHT: CGFloat = 120.0
    let SPACE_PICKER_STACK: CGFloat = 10.0
    @IBOutlet weak var siteLabel: UILabel!
    @IBOutlet weak var accountPicker: UIPickerView!
    @IBOutlet weak var pickerHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var spaceBetweenPickerAndStackview: NSLayoutConstraint!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        analyseRequest()
        
        accountPicker.dataSource = self
        accountPicker.delegate = self
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return UIStatusBarStyle.lightContent
    }
    
    // MARK: UIPickerView functions
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return accounts.count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return accounts[row].username
    }
    
    func pickerView(_ pickerView: UIPickerView, attributedTitleForRow row: Int, forComponent component: Int) -> NSAttributedString? {
        
        let username = NSAttributedString(string: accounts[row].username, attributes: [.foregroundColor : UIColor.white])
        return username
    }
    
    @IBAction func accept(_ sender: UIButton) {
        if let notification = notification, let session = session {
            switch notification.requestType {
            case .add:
                Site.get(id: notification.siteID, completion: { (site) in
                    self.site = site
                    DispatchQueue.main.async {
                        self.performSegue(withIdentifier: "RegistrationRequestSegue", sender: self)
                    }
                })
            case .login, .change:
                if accounts.count == 0 {
                    Site.get(id: notification.siteID, completion: { (site) in
                        self.site = site
                        DispatchQueue.main.async {
                            self.performSegue(withIdentifier: "RegistrationRequestSegue", sender: self)
                        }
                    })
                } else if accounts.count == 1 {
                    authorize(notification: notification, session: session, accountID: accounts.first!.id)
                } else {
                    let accountID = accounts[accountPicker.selectedRow(inComponent: 0)].id
                    authorize(notification: notification, session: session, accountID: accountID)
                }
            case .register:
                Logger.shared.debug("TODO: Fix register requests")
            default:
                Logger.shared.warning("Unknown request type received.")
            }
        }
    }
    
    @IBAction func reject(_ sender: UIButton) {
        if let notification = notification, let session = session {
            do {
                try session.acknowledge(browserTab: notification.browserTab)
            } catch {
                Logger.shared.error("Acknowledge could not be sent.", error: error as NSError)
            }
        }
        self.dismiss(animated: true, completion: nil)
        AuthenticationGuard.sharedInstance.authorizationInProgress = false
    }
    
    // MARK: Private functions
    
    private func authorize(notification: PushNotification, session: Session, accountID: String) {
        AuthenticationGuard.sharedInstance.authorizeRequest(siteName: notification.siteName, accountID: accountID, type: notification.requestType, completion: { [weak self] (succes, error) in
            if (succes) {
                DispatchQueue.main.async {
                    do {
                        let account = try Account.get(accountID: accountID)
                        try session.sendCredentials(account: account!, browserTab: notification.browserTab, type: notification.requestType)
                        self?.dismiss(animated: true, completion: nil)
                    } catch {
                        Logger.shared.error("Error authorizing request", error: error as NSError)
                    }
                }
            } else {
                Logger.shared.info("Request denied.", userInfo: ["code": AnalyticsMessage.requestDenied.rawValue, "result": false, "requestType": notification.requestType.rawValue])
                Logger.shared.debug("TODO: Handle touchID errors.")
            }
        })
    }

    private func analyseRequest() {
        if let notification = notification, let session = session {
            do {
                accounts = try Account.get(siteID: notification.siteID)
                if accounts.count > 1 {
                    pickerHeightConstraint.constant = PICKER_HEIGHT
                    spaceBetweenPickerAndStackview.constant = SPACE_PICKER_STACK
                } else if accounts.count == 1 {
                    if notification.requestType == .login || notification.requestType == .change {
                        authorize(notification: notification, session: session, accountID: accounts.first!.id)
                    }
                }
                setLabel(requestType: notification.requestType)
            } catch {
                Logger.shared.error("Could not get account.", error: error as NSError)
            }
        }
    }

    private func setLabel(requestType: BrowserMessageType) {
        switch requestType {
        case .login:
            siteLabel.text = !self.accounts.isEmpty ? "Login to \(notification!.siteName)?" : "Add \(notification!.siteName)?"
        case .change:
            siteLabel.text = !self.accounts.isEmpty ? "Change password for \(notification!.siteName)?" : "Add \(notification!.siteName)?"
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
        AuthenticationGuard.sharedInstance.authorizationInProgress = false
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



