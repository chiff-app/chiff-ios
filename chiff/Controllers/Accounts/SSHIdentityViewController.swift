//
//  DeveloperIdentityViewController.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import UIKit
import ChiffCore

class SSHIdentityViewController: ChiffTableViewController, UITextFieldDelegate {

    var identity: SSHIdentity!

    override var headers: [String?] {
        return [
            "developer.ssh_detail_header".localized,
            "developer.ssh_pubkey_header".localized
        ]
    }
    override var footers: [String?] {
        return [identity?.algorithm == .ECDSA256 ? "developer.ssh_detail_enclave_footer".localized : "developer.ssh_detail_footer".localized]
    }

    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var typeTextField: LocalizableTextField!
    @IBOutlet weak var pubKeyCell: MultiLineTextInputTableViewCell!

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.layer.borderColor = UIColor.primaryTransparant.cgColor
        tableView.layer.borderWidth = 1.0
        tableView.separatorColor = UIColor.primaryTransparant
        nameTextField.delegate = self
        nameTextField.text = identity.name
        typeTextField.text = "developer.algorithm".localized
        pubKeyCell.delegate = self
        if identity.algorithm == .ECDSA256 {
            typeTextField.text = "\(identity.algorithm.title) (Secure Enclave 🔑)"
        } else {
            typeTextField.text = identity.algorithm.title
        }
        pubKeyCell.textString = identity.publicKey

        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self.view, action: #selector(UIView.endEditing(_:))))
    }

    // MARK: - Actions

    @IBAction func deleteDevice(_ sender: UIButton) {
        let alert = UIAlertController(title: "\("popups.responses.delete".localized) \(identity.name)?", message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "popups.responses.cancel".localized, style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "popups.responses.delete".localized, style: .destructive, handler: { _ in
            self.performSegue(withIdentifier: "DeleteSSHIdentity", sender: self)
        }))
        self.present(alert, animated: true, completion: nil)
    }

}

extension SSHIdentityViewController: MultiLineTextInputTableViewCellDelegate {

    var maxCharacters: Int {
        return 4000
    }

    var placeholderText: String {
        return ""
    }

    func textViewHeightDidChange(_ cell: UITableViewCell) {
        UIView.setAnimationsEnabled(false)
        tableView?.beginUpdates()
        tableView?.endUpdates()
        UIView.setAnimationsEnabled(true)

        if let thisIndexPath = tableView?.indexPath(for: cell) {
            tableView?.scrollToRow(at: thisIndexPath, at: .bottom, animated: false)
        }
    }

}
