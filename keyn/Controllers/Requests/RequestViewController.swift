/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit
import LocalAuthentication

class RequestViewController: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource {
    @IBOutlet weak var siteLabel: UILabel!
    @IBOutlet weak var accountPicker: UIPickerView!
    @IBOutlet weak var pickerHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var spaceBetweenPickerAndStackview: NSLayoutConstraint!

    var type: KeynMessageType!
    var notification: PushNotification!
    var session: Session!

    private var site: Site?
    private var accounts = [Account]()
    private let PICKER_HEIGHT: CGFloat = 120.0
    private let SPACE_PICKER_STACK: CGFloat = 10.0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        analyseRequest()
        
        accountPicker.dataSource = self
        accountPicker.delegate = self
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return UIStatusBarStyle.lightContent
    }
    
    // MARK: - UIPickerView functions
    
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

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        if segue.identifier == "RegistrationRequestSegue", let destinationController = (segue.destination.contents) as? RegistrationRequestViewController {
            destinationController.site = site
            destinationController.session = session
            destinationController.notification = notification
        }
    }

    @IBAction func unwindToRequestViewController(sender: UIStoryboardSegue) {
        self.dismiss(animated: false, completion: nil)
        AuthorizationGuard.shared.authorizationInProgress = false
    }

    // MARK: - Actions

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
                Logger.shared.error("Could not get PPD.", error: error)
            }
        }
    }
    
    @IBAction func reject(_ sender: UIButton) {
        if let notification = notification, let session = session {
            session.reject(browserTab: notification.browserTab) { (_, error) in
                if let error = error {
                    Logger.shared.error("Reject message could not be sent.", error: error)
                }
            }
        }
        self.dismiss(animated: true, completion: nil)
        AuthorizationGuard.shared.authorizationInProgress = false
    }
    
    // MARK: - Private
    
    private func authorize(notification: PushNotification, session: Session, accountID: String, type: KeynMessageType) {
        AuthorizationGuard.shared.authorizeRequest(siteName: notification.siteName, accountID: accountID, type: type, completion: { [weak self] (succes, error) in
            if (succes) {
                DispatchQueue.main.async {
                    do {
                        let account = try Account.get(accountID: accountID)
                        try session.sendCredentials(account: account!, browserTab: notification.browserTab, type: type)
                        self?.dismiss(animated: true, completion: nil)
                    } catch {
                        Logger.shared.error("Error authorizing request", error: error)
                    }
                }
            } else {
                Logger.shared.analytics("Request denied.", code: .requestDenied, userInfo: ["result": false, "type": type.rawValue])
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
                    if (type == .login || type == .change || type == .fill) && !AuthenticationGuard.shared.hasFaceID() {
                        authorize(notification: notification, session: session, accountID: accounts.first!.id, type: type)
                    }
                }
                siteLabel.text = AuthorizationGuard.shared.requestText(siteName: notification.siteName, type: type, accountExists: accountExists())
            } catch {
                Logger.shared.error("Could not get account.", error: error)
                self.dismiss(animated: true, completion: nil)
            }
        }
    }
    
    private func accountExists() -> Bool {
        guard accounts.isEmpty else {
           return false
        }
        if let username = notification?.username {
            return accounts.contains { $0.username == username }
        }
        return true
    }
}
