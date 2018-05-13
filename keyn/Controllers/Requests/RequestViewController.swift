import UIKit
import LocalAuthentication

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
                    self.performSegue(withIdentifier: "RegistrationRequestSegue", sender: self)
                })
            case .login, .change:
                if accounts.count == 0 {
                    Site.get(id: notification.siteID, completion: { (site) in
                        self.site = site
                        self.performSegue(withIdentifier: "RegistrationRequestSegue", sender: self)
                    })
                } else if accounts.count == 1 {
                    authorize(notification: notification, session: session, accountID: accounts.first!.id)
                } else {
                    let accountID = accounts[accountPicker.selectedRow(inComponent: 0)].id
                    authorize(notification: notification, session: session, accountID: accountID)
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
        AuthenticationGuard.sharedInstance.authorizationInProgress = false
    }
    
    // MARK: Private functions
    
    private func authorize(notification: PushNotification, session: Session, accountID: String) {
        // TODO: Handle error throwing here
        AuthenticationGuard.sharedInstance.authorizeRequest(siteName: notification.siteName, accountID: accountID, type: notification.requestType, completion: { [weak self] (succes, error) in
            if (succes) {
                DispatchQueue.main.async {
                    var account = try! Account.get(accountID: accountID)
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
            // TODO: Crash app for now.
            print(notification.requestType)
            do {
                accounts = try! Account.get(siteID: notification.siteID)
                if accounts.count == 1 {
                    if notification.requestType == .login || notification.requestType == .change {
                        authorize(notification: notification, session: session, accountID: accounts.first!.id)
                    }
                } else {
                    pickerHeightConstraint.constant = PICKER_HEIGHT
                    spaceBetweenPickerAndStackview.constant = SPACE_PICKER_STACK
                }
                setLabel(requestType: notification.requestType)
            } catch {
                print("Error getting account: \(error)")
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



