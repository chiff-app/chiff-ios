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
                    self.acceptLoginChangeOrFillRequest()
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
        rejectRequest()
    }
    
    // MARK: - Private

    private func authorize(request: KeynRequest, session: Session, account: Account, type: KeynMessageType) {
        guard let browserTab = request.browserTab else {
            #warning("Show error to user that the request was not valid. Or perhaps check before and never call this function.")
            return
        }

        DispatchQueue.global().async {
            do {
                try session.sendCredentials(account: account, browserTab: browserTab, type: type)
                DispatchQueue.main.async { [weak self] in
                    self?.dismiss(animated: true, completion: nil)
                }
            } catch {
                Logger.shared.error("Error authorizing request", error: error)
            }
        }
    }

    private func analyseRequest() {
        if let request = request, let session = session, let siteID = request.siteID {
            accounts = Account.get(siteID: siteID)
            if !accountExists() {
                Logger.shared.error("RequestViewController could not get accounts.")
                #warning("TODO: Show message to user.")
                self.dismiss(animated: true, completion: nil)
            } else if accounts.count > 1 {
                pickerHeightConstraint.constant = PICKER_HEIGHT
                spaceBetweenPickerAndStackview.constant = SPACE_PICKER_STACK
            } else if accounts.count == 1 {
                if (type == .login || type == .change || type == .fill) && !AuthenticationGuard.shared.hasFaceID() {
                    authorize(request: request, session: session, account: accounts.first!, type: type)
                }
            }
            siteLabel.text = AuthorizationGuard.shared.textLabelFor(siteName: request.siteName ?? "", type: type, accountExists: accountExists())
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

        try PPD.get(id: siteID, completionHandler: { (ppd) in
            let site = Site(name: request.siteName ?? ppd?.name ?? "Unknown", id: siteID, url: request.siteURL ?? ppd?.url ?? "https://", ppd: ppd)
            do {
                let account = try Account(username: username, sites: [site], password: password)
                try session.sendCredentials(account: account, browserTab: browserTab, type: request.type)
                NotificationCenter.default.post(name: .accountAdded, object: nil, userInfo: ["account": account])
                DispatchQueue.main.async { [weak self] in
                    self?.dismiss(animated: true, completion: nil)
                }
            } catch {
                #warning("TODO: Show the user that the account could not be added.")
                Logger.shared.error("Account could not be saved.", error: error)
            }
        })
    }

    /*
     * These three scenarios have the same codepath:
     * - get credentials for login
     * - request a change of password
     * - request for filling password in specific field
     */
    private func acceptLoginChangeOrFillRequest() {
        if accounts.count <= 0 {
            // Not possible because we just called analyseRequest()
        } else if accounts.count == 1 {
            authorize(request: request, session: session, account: accounts.first!, type: type)
        } else {
            let account = accounts[accountPicker.selectedRow(inComponent: 0)]
            authorize(request: request, session: session, account: account, type: type)
        }
    }

    #warning("TODO: Implement acceptRegisterRequest in RequestViewController")
    private func acceptRegisterRequest() {
        Logger.shared.debug("TODO: Implement acceptRegisterRequest in RequestViewController.")
//        try PPD.get(id: siteID, completionHandler: { (ppd) in
//            let site = Site(name: self.request.siteName ?? ppd?.name ?? "Unknown", id: siteID, url: self.request.siteURL ?? ppd?.url ?? "https://", ppd: ppd)
//            self.site = site
//            DispatchQueue.main.async {
//                self.performSegue(withIdentifier: "RegistrationRequestSegue", sender: self)
//            }
//        })
    }

    private func rejectRequest() {
        if let request = request, let session = session, let browserTab = request.browserTab {
            session.cancelRequest(reason: .reject, browserTab: browserTab) { (_, error) in
                if let error = error {
                    Logger.shared.error("Reject message could not be sent.", error: error)
                }
            }
        }
        self.dismiss(animated: true, completion: nil)
        AuthorizationGuard.shared.authorizationInProgress = false
    }
}
