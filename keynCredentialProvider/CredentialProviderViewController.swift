/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import AuthenticationServices
import LocalAuthentication

class CredentialProviderViewController: UIViewController, UITableViewDataSource, UISearchResultsUpdating, UITableViewDelegate {

    @IBOutlet weak var tableView: UITableView!
    var unfilteredAccounts: [Account]!
    var filteredAccounts: [Account]!
    var credentialExtensionContext: ASCredentialProviderExtensionContext!
//    let searchController = UISearchController(searchResultsController: nil)

    override func viewDidLoad() {
        super.viewDidLoad()
        filteredAccounts = unfilteredAccounts
        tableView.delegate = self
        tableView.dataSource = self
//        searchController.searchResultsUpdater = self
//        searchController.searchBar.searchBarStyle = .minimal
//        searchController.hidesNavigationBarDuringPresentation = true
//        searchController.dimsBackgroundDuringPresentation = false
        self.extendedLayoutIncludesOpaqueBars = false
        self.definesPresentationContext = true
//        navigationItem.searchController = searchController
    }
    
    // MARK: - Actions
    
    @IBAction func cancel(_ sender: AnyObject?) {
        credentialExtensionContext.cancelRequest(withError: NSError(domain: ASExtensionErrorDomain, code: ASExtensionError.userCanceled.rawValue))
    }
    
    // MARK: - SearchController
    
    func updateSearchResults(for searchController: UISearchController) {
        if let searchText = searchController.searchBar.text, !searchText.isEmpty {
            filteredAccounts = unfilteredAccounts.filter({ (account) -> Bool in
                return account.site.name.lowercased().contains(searchText.lowercased())
            }).sorted(by: { (first, second) -> Bool in
                first.site.name < second.site.name
            })
        } else {
            filteredAccounts = unfilteredAccounts.sorted(by: { (first, second) -> Bool in
                first.site.name < second.site.name
            })
        }

        tableView.reloadData()
    }
    
    // MARK: - Table view data source
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let accounts = filteredAccounts else {
            return 0
        }

        return accounts.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "AccountCell", for: indexPath) as! AccountTableViewCell
        //        cell.contentView.layoutMargins = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
        let account = filteredAccounts[indexPath.row]
        cell.titleLabel.text = account.site.name
        return cell
    }
    
    // MARK: - Table view delegate
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let account = filteredAccounts?[indexPath.row] {
            do {
                let password = try account.password(context: nil)
                let passwordCredential = ASPasswordCredential(user: account.username, password: password)
                credentialExtensionContext.completeRequest(withSelectedCredential: passwordCredential, completionHandler: nil)
            } catch {
                credentialExtensionContext.cancelRequest(withError: NSError(domain: ASExtensionErrorDomain, code: ASExtensionError.failed.rawValue))
            }
        }
    }

}
