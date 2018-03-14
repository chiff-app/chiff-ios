import UIKit

protocol canReceiveSession {
    func addSession(session: Session)
}

class DevicesViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, canReceiveSession {
    
    var sessions = [Session]()
    @IBOutlet weak var tableView: UITableView!

    override func viewDidLoad() {
        super.viewDidLoad()
        do {
            if let storedSessions = try Session.all() {
                print("Loading sessions from keychain.")
                sessions = storedSessions
            }
        } catch {
            print("Sessions could not be loaded: \(error)")
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let selectedIndexPath = tableView.indexPathForSelectedRow {
            tableView.deselectRow(at: selectedIndexPath, animated: true)
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch indexPath.section {
        case 0:
            return 90
        case 1:
            return 44
        default:
            assert(false, "section \(indexPath.section)")
        }
    }
    
    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch section {
        case 0:
            return nil
        case 1:
            return "Open the Keyn browser extension to display QR-code."
        default:
            assert(false, "section \(section)")
        }
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return "devices"
        case 1:
            return nil
        default:
            assert(false, "section \(section)")
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return sessions.count
        case 1:
            return 1
        default:
            assert(false, "section \(section)")
        }
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    @objc func deleteDevice(_ sender: UIButton) {
        let buttonPosition = sender.convert(CGPoint(), to:tableView)
        if let indexPath = tableView.indexPathForRow(at:buttonPosition) {
            let session = sessions[indexPath.row]
            let alert = UIAlertController(title: "Remove \(session.browser) on \(session.os)?", message: nil, preferredStyle: .actionSheet)
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            alert.addAction(UIAlertAction(title: "Remove", style: .destructive, handler: { action in
                do {
                    try self.sessions[indexPath.row].delete()
                    self.sessions.remove(at: indexPath.row)
                    self.tableView.deleteRows(at: [indexPath], with: .automatic)
                    if self.sessions.isEmpty {
                        DispatchQueue.main.async {
                            let qrViewController = self.storyboard?.instantiateViewController(withIdentifier: "QR Controller")
                            self.navigationController?.setViewControllers([qrViewController!], animated: false)
                        }
                    }
                } catch {
                    print("Session could not be deleted: \(error)")
                }
            }))
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case 0:
            let cell = tableView.dequeueReusableCell(withIdentifier: "Device Cell", for: indexPath)
            if let cell = cell as? DevicesViewCell {
                let session = sessions[indexPath.row]
                cell.titleLabel.text = "\(session.browser) on \(session.os)"
                cell.timestampLabel.text = session.creationDate.timeAgoSinceNow()
                cell.deviceLogo.image = UIImage(named: "Chrome")
                cell.deleteButton.addTarget(self, action: #selector(deleteDevice(_:)), for: .touchUpInside)
            }
            return cell
        case 1:
            let cell = tableView.dequeueReusableCell(withIdentifier: "Scan QR", for: indexPath)
            cell.textLabel?.text = "Scan QR"
            return cell
        default:
            assert(false, "section \(indexPath.section)")
        }
    }
    
    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "Add Session" {
            if let destination = (segue.destination.contents) as? QRViewController {
                destination.devicesDelegate = self
            }
        }
    }

    //MARK: Actions
    
    func addSession(session: Session) {
        let newIndexPath = IndexPath(row: sessions.count, section: 0)
        sessions.append(session)
        tableView.insertRows(at: [newIndexPath], with: .automatic)
    }

}
