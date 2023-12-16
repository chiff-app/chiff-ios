//
//  AddOTPViewController.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import UIKit
import LocalAuthentication
import OneTimePassword
import PromiseKit
import ChiffCore

class AddOTPViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var searchBar: UISearchBar!

    var otpUrl: URL!
    var unfilteredAccounts: [UserAccount]!
    var filteredAccounts: [UserAccount]!
    var addAccountButton: KeynBarButton?
    var sortingButton: AccountsPickerButton!
    var currentFilter = Filters.all
    var currentSortingValue = Properties.sortingPreference
    var searchQuery = ""

    override func viewDidLoad() {
        super.viewDidLoad()
        if let accountDict = try? UserAccount.all(context: nil) {
            unfilteredAccounts = Array(accountDict.values).sorted(by: { $0.name.lowercased() < $1.name.lowercased() })
        } else {
            unfilteredAccounts = [UserAccount]()
        }
        filteredAccounts = unfilteredAccounts.sorted(by: { $0.site.name.lowercased() < $1.site.name.lowercased() })
        tableView.delegate = self
        tableView.dataSource = self

        self.extendedLayoutIncludesOpaqueBars = false
        self.definesPresentationContext = true

        searchBar.placeholder = "accounts.search".localized
        searchBar.setScopeBarButtonTitleTextAttributes([
            NSAttributedString.Key.font: UIFont.primaryMediumNormal as Any,
            NSAttributedString.Key.foregroundColor: UIColor.primary
        ], for: .normal)
        searchBar.scopeButtonTitles = [
            Filters.all.text(),
            Filters.team.text(),
            Filters.personal.text()
        ]
        searchBar.delegate = self
        
        if addAccountButton == nil {
            addAccountButton = KeynBarButton(frame: CGRect(x: 0, y: 0, width: 30, height: 30))
            addAccountButton!.setImage(UIImage(named: "add_button"), for: .normal)
        }
        addAccountButton!.addTarget(self, action: #selector(showAddAccount), for: .touchUpInside)
        self.navigationItem.rightBarButtonItem = addAccountButton!.barButtonItem
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "ShowAddAccount", let destination = segue.destination as? AddAccountViewController {
            // TODO: Set OTP URL
        }
    }

    // MARK: - Actions

    @IBAction func cancel(_ sender: AnyObject?) {
        dismiss(animated: true, completion: nil)
    }

    @objc private func showAddAccount() {
        performSegue(withIdentifier: "ShowAddAccount", sender: self)
    }

    // MARK: - Table view data source

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let accounts = filteredAccounts else {
            return 0
        }

        return accounts.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var identifier: String!
        if let account = filteredAccounts[indexPath.row] as? UserAccount {
            identifier = account.shadowing ? "ShadowingCell" : "AccountCell"
        } else {
            identifier = "TeamsCell"
        }
        return tableView.dequeueReusableCell(withIdentifier: identifier, for: indexPath)
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let cell = cell as? AccountTableViewCell else {
            return
        }
        let account = filteredAccounts[indexPath.row]
        cell.titleLabel.text = account.name
        if #available(iOS 13.0, *), let cell = cell as? SharedAccountTableViewCell {
            cell.teamIcon.image = UIImage(systemName: "person.2.fill")
        }
    }

    // MARK: - Table view delegate

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let account = filteredAccounts?[indexPath.row] else {
            return
        }
        guard otpUrl.chiffType == .otp else {
            showAlert(message: "errors.session_invalid".localized, handler: nil)
            return
        }
        guard let token = Token(url: otpUrl) else {
            Logger.shared.error("Error creating OTP token")
            showAlert(message: "errors.token_creation".localized, handler: nil)
            return
        }
        if account.hasOtp {
            let alert = UIAlertController(title: "popups.questions.has_otp_title".localized, message: "popups.questions.has_otp_message".localized, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "popups.responses.cancel".localized, style: .cancel, handler: nil))
            alert.addAction(UIAlertAction(title: "popups.responses.update".localized, style: .destructive, handler: { _ in
                self.addOTP(account: account, token: token)
            }))
            self.present(alert, animated: true)
            return
        } else {
            addOTP(account: account, token: token)
        }
    }

    // MARK: - Private functions


    private func addOTP(account: UserAccount, token: Token) {
        firstly {
            AuthorizationGuard.shared.addOTP(token: token, account: account)
        }.done(on: .main) {
            self.dismiss(animated: true)
        }.catch(on: .main) { error in
            Logger.shared.error("Error adding OTP", error: error)
            self.showAlert(message: "errors.add_otp".localized, handler: nil)
        }
    }

}
