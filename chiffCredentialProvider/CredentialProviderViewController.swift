//
//  CredentialProviderViewController.swift
//  chiffCredentialProvider
//
//  Copyright: see LICENSE.md
//

import AuthenticationServices
import LocalAuthentication
import ChiffCore

class CredentialProviderViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var searchBar: UISearchBar!

    var unfilteredAccounts: [Account]!
    var filteredAccounts: [Account]!
    var credentialExtensionContext: ASCredentialProviderExtensionContext!
    var serviceIdentifiers: [ASCredentialServiceIdentifier]!
    var addAccountButton: KeynBarButton?
    var sortingButton: AccountsPickerButton!
    var currentFilter = Filters.all
    var currentSortingValue = Properties.sortingPreference
    var searchQuery = ""

    override func viewDidLoad() {
        super.viewDidLoad()
        updateUI()
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
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "ShowAddAccount", let destination = segue.destination as? AddAccountViewController {
            destination.credentialExtensionContext = self.credentialExtensionContext
            destination.serviceIdentifiers = self.serviceIdentifiers
        }
    }

    // MARK: - Actions

    @IBAction func cancel(_ sender: AnyObject?) {
        credentialExtensionContext.cancelRequest(withError: NSError(domain: ASExtensionErrorDomain, code: ASExtensionError.userCanceled.rawValue))
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
        if let account = filteredAccounts?[indexPath.row] {
            do {
                guard let password = try account.password(context: nil) else {
                    credentialExtensionContext.cancelRequest(withError: NSError(domain: ASExtensionErrorDomain, code: ASExtensionError.failed.rawValue))
                    return
                }
                let passwordCredential = ASPasswordCredential(user: account.username, password: password)
                credentialExtensionContext.completeRequest(withSelectedCredential: passwordCredential, completionHandler: nil)
            } catch {
                credentialExtensionContext.cancelRequest(withError: NSError(domain: ASExtensionErrorDomain, code: ASExtensionError.failed.rawValue))
            }
        }
    }

    // MARK: - Private functions

    private func updateUI() {
        UINavigationBar.appearance().setBackgroundImage(UIImage(), for: .default)
        UINavigationBar.appearance().shadowImage = UIImage()
        UINavigationBar.appearance().isTranslucent = true
        UINavigationBar.appearance().backIndicatorImage = UIImage(named: "chevron_left")?.withInsets(UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10))
        UINavigationBar.appearance().backIndicatorTransitionMaskImage =  UIImage(named: "chevron_left")?.withInsets(UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10))
        UIBarButtonItem.appearance().setTitleTextAttributes([.foregroundColor: UIColor.primary,
                                                             .font: UIFont.primaryBold!], for: UIControl.State.normal)
        UIBarButtonItem.appearance().setTitleTextAttributes([.font: UIFont.primaryBold!], for: UIControl.State.highlighted)
        UIBarButtonItem.appearance().setTitleTextAttributes([.font: UIFont.primaryBold!], for: UIControl.State.selected)
        UIBarButtonItem.appearance().setTitleTextAttributes([.font: UIFont.primaryBold!], for: UIControl.State.focused)
        UIBarButtonItem.appearance().setTitleTextAttributes([.foregroundColor: UIColor.primaryHalfOpacity,
                                                             .font: UIFont.primaryBold!], for: UIControl.State.disabled)
        if addAccountButton == nil {
            addAccountButton = KeynBarButton(frame: CGRect(x: 0, y: 0, width: 30, height: 30))
            addAccountButton!.setImage(UIImage(named: "add_button"), for: .normal)
        }
        addAccountButton!.addTarget(self, action: #selector(showAddAccount), for: .touchUpInside)
        self.navigationItem.rightBarButtonItem = addAccountButton!.barButtonItem
    }

}
