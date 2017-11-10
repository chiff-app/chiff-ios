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
            userPasswordTextField.text = account.password()
            navigationItem.title = account.site.name
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
    
    
    // MARK: Private methods
    
    private func showHiddenPasswordPopup() {
        let showPasswordHUD = MBProgressHUD.showAdded(to: self.view, animated: true)
        showPasswordHUD.mode = .text
        showPasswordHUD.label.text = userPasswordTextField.text
        showPasswordHUD.label.textColor = .black
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
