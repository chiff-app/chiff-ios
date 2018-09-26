import UIKit
import LocalAuthentication
import JustLog

class RequestViewController: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource {

    var notification: PushNotification!
    var type: BrowserMessageType!
    var session: Session!
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
        if let notification = notification, let session = session, let type = type {
            do {
                switch type {
                case .add:
                    try Site.get(id: notification.siteID, completion: { (site) in
                        self.site = site
                        DispatchQueue.main.async {
                            self.performSegue(withIdentifier: "RegistrationRequestSegue", sender: self)
                        }
                    })
                case .login, .change, .fill:
                    if accounts.count == 0 {
                        try Site.get(id: notification.siteID, completion: { (site) in
                            self.site = site
                            DispatchQueue.main.async {
                                self.performSegue(withIdentifier: "RegistrationRequestSegue", sender: self)
                            }
                        })
                    } else if accounts.count == 1 {
                        authorize(notification: notification, session: session, accountID: accounts.first!.id, type: type)
                    } else {
                        let accountID = accounts[accountPicker.selectedRow(inComponent: 0)].id
                        authorize(notification: notification, session: session, accountID: accountID, type: type)
                    }
                case .register:
                    Logger.shared.debug("TODO: Fix register requests")
                default:
                    Logger.shared.warning("Unknown request type received.")
                }
            } catch {
                Logger.shared.error("Could nog get PPD.", error: error as NSError)
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
    
    private func authorize(notification: PushNotification, session: Session, accountID: String, type: BrowserMessageType) {
        AuthenticationGuard.sharedInstance.authorizeRequest(siteName: notification.siteName, accountID: accountID, type: type, completion: { [weak self] (succes, error) in
            if (succes) {
                DispatchQueue.main.async {
                    do {
                        let account = try Account.get(accountID: accountID)
                        try session.sendCredentials(account: account!, browserTab: notification.browserTab, type: type)
                        self?.dismiss(animated: true, completion: nil)
                    } catch {
                        Logger.shared.error("Error authorizing request", error: error as NSError)
                    }
                }
            } else {
                Logger.shared.info("Request denied.", userInfo: ["code": AnalyticsMessage.requestDenied.rawValue, "result": false, "requestType": type.rawValue])
                Logger.shared.debug("TODO: Handle touchID errors.")
            }
        })
    }

    private func analyseRequest() {
        if let notification = notification, let session = session {
            do {
                accounts = try Account.get(siteID: notification.siteID)
                if !accountExists() {
                    type = .add
                } else if accounts.count > 1 {
                    pickerHeightConstraint.constant = PICKER_HEIGHT
                    spaceBetweenPickerAndStackview.constant = SPACE_PICKER_STACK
                } else if accounts.count == 1 {
                    if (type == .login || type == .change || type == .fill) && !AuthenticationGuard.sharedInstance.hasFaceID() {
                        authorize(notification: notification, session: session, accountID: accounts.first!.id, type: type)
                    }
                }
                setLabel(requestType: type)
            } catch {
                Logger.shared.error("Could not get account.", error: error as NSError)
                self.dismiss(animated: true, completion: nil)
            }
        }
    }
    
    private func accountExists() -> Bool {
        if self.accounts.isEmpty {
            return false
        } else if let username = notification?.username {
            return accounts.contains { (account) -> Bool in
                account.username == username
            }
        }
        return true
    }

    private func setLabel(requestType: BrowserMessageType) {
        switch requestType {
        case .login:
            siteLabel.text = "Login to \(notification!.siteName)?"
        case .fill:
            siteLabel.text = "Fill password for \(notification!.siteName)?"
        case .change:
            siteLabel.text = accountExists() ? "Change password for \(notification!.siteName)?" : "Add \(notification!.siteName)?"
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



