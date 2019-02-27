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
    var request: KeynRequest!
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

    // MARK: - Actions

    @IBAction func accept(_ sender: UIButton) {
        if let request = request, let session = session, let type = type {
            do {
                switch type {
                case .add:
                    try self.acceptAddRequest(request: request, session: session) // WIP HERE
                case .login, .change, .fill:
                    try self.acceptLoginChangeOrFillRequest()
                case .register:
                    self.acceptRegisterRequest()
                default:
                    Logger.shared.warning("Unknown request type received.")
                }
            } catch {
                Logger.shared.error("Could not get PPD.", error: error)
            }
        }
    }
    
    @IBAction func reject(_ sender: UIButton) {
        if let request = request, let session = session, let browserTab = request.browserTab {
            session.reject(browserTab: browserTab) { (_, error) in
                if let error = error {
                    Logger.shared.error("Reject message could not be sent.", error: error)
                }
            }
        }
        self.dismiss(animated: true, completion: nil)
        AuthorizationGuard.shared.authorizationInProgress = false
    }
    
    // MARK: - Private

    private func authorize(request: KeynRequest, session: Session, accountID: String, type: KeynMessageType) {
        guard let siteName = request.siteName, let browserTab = request.browserTab else {
            #warning("Show error to user that the request was not valid. Or perhaps check before and never call this function.")
            return
        }

        AuthorizationGuard.shared.authorizeRequest(siteName: siteName, accountID: accountID, type: type) { [weak self] (succes, error) in
            if (succes) {
                DispatchQueue.main.async {
                    do {
                        let account = try Account.get(accountID: accountID)
                        try session.sendCredentials(account: account!, browserTab: browserTab, type: type)
                        self?.dismiss(animated: true, completion: nil)
                    } catch {
                        Logger.shared.error("Error authorizing request", error: error)
                    }
                }
            } else {
                Logger.shared.analytics("Request denied.", code: .requestDenied, userInfo: ["result": false, "type": type.rawValue])
                #warning("TODO: Some user interaction generates touchID errors? Check if we get here not when user denied but when these kinds of error occured.")
                Logger.shared.debug("TODO: Handle touchID errors.")
            }
        }
    }

    private func analyseRequest() {
        if let request = request, let session = session, let siteID = request.siteID {
            do {
                accounts = try Account.get(siteID: siteID)
                if !accountExists() {
                    type = .add
                } else if accounts.count > 1 {
                    pickerHeightConstraint.constant = PICKER_HEIGHT
                    spaceBetweenPickerAndStackview.constant = SPACE_PICKER_STACK
                } else if accounts.count == 1 {
                    if (type == .login || type == .change || type == .fill) && !AuthenticationGuard.shared.hasFaceID() {
                        authorize(request: request, session: session, accountID: accounts.first!.id, type: type)
                    }
                }
                siteLabel.text = AuthorizationGuard.shared.requestText(siteName: request.siteName ?? "", type: type, accountExists: accountExists())
            } catch {
                Logger.shared.error("Could not get account.", error: error)
                self.dismiss(animated: true, completion: nil)
            }
        }
    }
    
    private func accountExists() -> Bool {
        if accounts.isEmpty {
            return false
        }
        if let username = request?.username {
            return accounts.contains { $0.username == username }
        }
        return true
    }

    private func acceptAddRequest(request: KeynRequest, session: Session) throws {
        guard let browserTab = request.browserTab else {
            Logger.shared.error("Cannot accept the add site request because there is no browserTab to send the reply back to.")
            return
        }
        guard let siteID = request.siteID else {
            Logger.shared.error("Cannot accept the add site request because there is no site ID.")
            return
        }
        guard let password = request.password else {
            Logger.shared.error("Cannot accept the add site request because there is no password.")
            return
        }
        guard let username = request.username else {
            Logger.shared.error("Cannot accept the add site request because there is no username.")
            return
        }

        try Site.get(id: siteID) { (site) in
            guard let site = site else {
                #warning("TODO: We don't have a site object here but we do want to add the account. Solve!")
                return
            }

            AuthorizationGuard.shared.authorizeRequest(siteName: site.name, accountID: nil, type: request.type) { [weak self] (succes, error) in
                if (succes) {
                    DispatchQueue.main.async {
                        do {
                            let account = try Account(username: username, site: site, password: password)
                            try session.sendCredentials(account: account, browserTab: browserTab, type: request.type)
                            NotificationCenter.default.post(name: .accountAdded, object: nil, userInfo: ["account": account])
                        } catch {
                            #warning("TODO: Show the user that the account could not be added.")
                            Logger.shared.error("Account could not be saved.", error: error)
                        }
//                        self?.performSegue(withIdentifier: "UnwindToRequestViewController", sender: self)
                        #warning("TODO: Go to the request completed view (to be made)")
                        self?.dismiss(animated: true, completion: nil)
                    }
                } else {
                    #warning("TODO: Some user interaction generates touchID errors? Check if we get here not when user denied but when these kinds of error occured.")
                    Logger.shared.debug("TODO: Handle touchID errors.")
                }
            }
        }
    }

    private func acceptLoginChangeOrFillRequest() throws {
        if accounts.count == 0 {
            guard let siteID = request.siteID else {
                #warning("TODO: We don't have a site object here but we do want to add the account. Solve!")
                return
            }

            try Site.get(id: siteID) { (site) in
                self.site = site
                DispatchQueue.main.async {
                    self.performSegue(withIdentifier: "RegistrationRequestSegue", sender: self)
                }
            }
        } else if accounts.count == 1 {
            authorize(request: request, session: session, accountID: accounts.first!.id, type: type)
        } else {
            let accountID = accounts[accountPicker.selectedRow(inComponent: 0)].id
            authorize(request: request, session: session, accountID: accountID, type: type)
        }
    }

    #warning("TODO: Implement acceptRegisterRequest in RequestViewController")
    private func acceptRegisterRequest() {
        Logger.shared.debug("TODO: Implement acceptRegisterRequest in RequestViewController.")
    }
}
