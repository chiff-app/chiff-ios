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

    var authorizationGuard: AuthorizationGuard!

    private var accounts = [Account]()
    private let PICKER_HEIGHT: CGFloat = 120.0
    private let SPACE_PICKER_STACK: CGFloat = 10.0
    
    override func viewDidLoad() {
        super.viewDidLoad()

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
        do {
            try authorizationGuard.acceptRequest {
                self.dismiss(animated: true, completion: nil)
            }
        } catch {
            #warning("TODO: SHow error")
        }
    }
    
    @IBAction func reject(_ sender: UIButton) {
        authorizationGuard.rejectRequest() {
            self.dismiss(animated: true, completion: nil)
        }
    }

}
