import UIKit
import MBProgressHUD

class AccountViewController: UITableViewController {

    //MARK: Properties

    var account: Account?
    
    @IBOutlet weak var websiteNameTextField: UITextField!
    @IBOutlet weak var websiteURLTextField: UITextField!
    @IBOutlet weak var userNameTextField: UITextField!
    @IBOutlet weak var userPasswordTextField: UITextField!
    @IBOutlet weak var showPasswordButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        if let account = account {
            websiteNameTextField.text = account.site.name
            websiteURLTextField.text = account.site.urls[0]
            userNameTextField.text = account.username
            do {
                userPasswordTextField.text = try account.password()
            } catch {
                // TODO: Password could not be loaded, present error?
                print(error)
            }
            navigationItem.title = account.site.name
            navigationItem.largeTitleDisplayMode = .never
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    // MARK: Actions
    
    @IBAction func showPassword(_ sender: UIButton) {
        showHiddenPasswordPopup()
    }
    
    @IBAction func deleteAccount(_ sender: UIButton) {
        let alert = UIAlertController(title: "Delete account?", message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { action in
            self.performSegue(withIdentifier: "DeleteAccount", sender: self)
        }))
        self.present(alert, animated: true, completion: nil)
    }


    // MARK: Private methods
    
    private func showHiddenPasswordPopup() {
        let showPasswordHUD = MBProgressHUD.showAdded(to: self.tableView.superview!, animated: true)
        showPasswordHUD.mode = .text
        showPasswordHUD.bezelView.color = .black
        showPasswordHUD.label.text = userPasswordTextField.text
        showPasswordHUD.label.textColor = .white
        showPasswordHUD.label.font = UIFont(name: "Courier New", size: 24)
        showPasswordHUD.margin = 10
        showPasswordHUD.label.numberOfLines = 0
        showPasswordHUD.removeFromSuperViewOnHide = true
        showPasswordHUD.addGestureRecognizer(
            UITapGestureRecognizer(
                target: showPasswordHUD,
                action: #selector(showPasswordHUD.hide(animated:)))
        )
    }

}
