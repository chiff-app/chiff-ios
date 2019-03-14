/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import AuthenticationServices
import LocalAuthentication

class CredentialProviderViewController: UIViewController, UITableViewDataSource, UISearchResultsUpdating, UITableViewDelegate {

    @IBOutlet weak var tableView: UITableView!
    var filteredAccounts: [Account]!
    let searchController = UISearchController(searchResultsController: nil)
    
    override func viewDidLoad() {
        super.viewDidLoad()

        UINavigationBar.appearance().shadowImage = UIImage(color: UIColor(rgb: 0x4932A2), size: CGSize(width: UIScreen.main.bounds.width, height: 1))

        filteredAccounts = Account.all.values.sorted(by: { $0.site.name < $1.site.name })

        tableView.delegate = self
        tableView.dataSource = self
        searchController.searchResultsUpdater = self
        searchController.searchBar.searchBarStyle = .minimal
        searchController.hidesNavigationBarDuringPresentation = true
        searchController.dimsBackgroundDuringPresentation = false
        self.extendedLayoutIncludesOpaqueBars = false
        self.definesPresentationContext = true
        navigationItem.searchController = searchController
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if let navigationView = navigationController?.view {
            fixShadowImage(inView: navigationView)
        }
    }
    
    // This fixes the navigationBar.shadowImage bug: https://forums.developer.apple.com/message/259206#259206
    func fixShadowImage(inView view: UIView) {
        if let imageView = view as? UIImageView {
            let size = imageView.bounds.size.height
            if size <= 1 && size > 0 &&
                imageView.subviews.count == 0,
                let components = imageView.backgroundColor?.cgColor.components, components == [0.0, 0.0, 0.0, 0.3]
            {
                let line = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 2))
                line.backgroundColor = UIColor(rgb: 0x4932A2)
                imageView.addSubview(line)
                line.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            }
        }

        for subview in view.subviews {
            fixShadowImage(inView: subview)
        }
    }
    
    // MARK: - Actions
    
    @IBAction func cancel(_ sender: AnyObject?) {
        Extension.extensionContext.cancelRequest(withError: NSError(domain: ASExtensionErrorDomain, code: ASExtensionError.userCanceled.rawValue))
    }
    
    // MARK: - SearchController
    
    func updateSearchResults(for searchController: UISearchController) {
        if let searchText = searchController.searchBar.text, !searchText.isEmpty {
            filteredAccounts = Account.all.values.filter({ (account) -> Bool in
                return account.site.name.lowercased().contains(searchText.lowercased())
            }).sorted(by: { (first, second) -> Bool in
                first.site.name < second.site.name
            })
        } else {
            filteredAccounts = Account.all.values.sorted(by: { (first, second) -> Bool in
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
        let cell = tableView.dequeueReusableCell(withIdentifier: "AccountCell", for: indexPath)
        
        if let accounts = filteredAccounts {
            let account = accounts[indexPath.row]
            cell.textLabel?.text = account.site.name
            cell.detailTextLabel?.text = account.username
        }

        return cell
    }
    
    // MARK: - Table view delegate
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let account = filteredAccounts?[indexPath.row] {
            do {
                let password = try account.password(reason: "Get password for \(account.site.name)", context: Extension.localAuthenticationContext)
                let passwordCredential = ASPasswordCredential(user: account.username, password: password)
                Extension.extensionContext.completeRequest(withSelectedCredential: passwordCredential, completionHandler: nil)
            } catch {
                Extension.extensionContext.cancelRequest(withError: NSError(domain: ASExtensionErrorDomain, code: ASExtensionError.failed.rawValue))
            }

        }
    }

}
