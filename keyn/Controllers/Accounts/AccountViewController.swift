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
            do {
                websiteNameTextField.text = account.site.name
                websiteURLTextField.text = account.site.urls[0]
                userNameTextField.text = account.username
                userPasswordTextField.text = try! account.password()
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

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 1 && indexPath.row == 1 {
            copyPassword(indexPath)
        }
    }


    // MARK: Private methods
    
    private func showHiddenPasswordPopup() {
        let showPasswordHUD = MBProgressHUD.showAdded(to: self.tableView.superview!, animated: true)
        showPasswordHUD.mode = .text
        showPasswordHUD.bezelView.color = .black
        showPasswordHUD.label.text = try! account?.password() ?? "Error fetching password"
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

    private func copyPassword(_ indexPath: IndexPath) {

        guard let passwordCell = tableView.cellForRow(at: indexPath) else {
            return
        }

        let pasteBoard = UIPasteboard.general
        pasteBoard.string = userPasswordTextField.text

        let copiedLabel = UILabel(frame: passwordCell.bounds)
        copiedLabel.text = "Copied"
        copiedLabel.font = copiedLabel.font.withSize(18)
        copiedLabel.textAlignment = .center
        copiedLabel.textColor = .white
        copiedLabel.backgroundColor = UIColor(displayP3Red: 0.85, green: 0.85, blue: 0.85, alpha: 1)

        passwordCell.addSubview(copiedLabel)

        UIView.animate(withDuration: 0.5, delay: 1.0, options: [.curveLinear], animations: {
            copiedLabel.alpha = 0.0
        }) { if $0 { copiedLabel.removeFromSuperview() } }
    }

}
