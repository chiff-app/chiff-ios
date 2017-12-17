import UIKit

protocol isAbleToReceiveData {
    func addSession(session: Session)
}


class DevicesViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, isAbleToReceiveData {

    var sessions = [Session]()
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var noSessionsView: UIView!

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        do {
            // TODO: Now retrieves sessions from Keychain every time view appears. Perhaps can be implemented more efficient.
            if let storedSessions = try Session.all() {
                print("Loading sessions from keychain.")
                sessions = storedSessions
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                    self.noSessionsView.isHidden = true
                }
            } else {
                self.noSessionsView.isHidden = false
            }
        } catch {
            print("Sessions could not be loaded: \(error)")
        }
    }

    // MARK: - Table view data source

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sessions.count
    }

    @objc func deleteDevice(_ sender: UIButton) {
        let buttonPosition = sender.convert(CGPoint(), to:tableView)
        if let indexPath = tableView.indexPathForRow(at:buttonPosition) {
            do {
                try sessions[indexPath.row].delete()
                sessions.remove(at: indexPath.row)
                tableView.deleteRows(at: [indexPath], with: .automatic)
                if sessions.isEmpty {
                    DispatchQueue.main.async {
                        self.noSessionsView.isHidden = false
                    }
                }
            } catch {
                print("Session could not be deleted: \(error)")
            }

        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Device Cell", for: indexPath)
        if let cell = cell as? DeviceTableViewCell {
            let session = sessions[indexPath.row]
            cell.deviceName.text = "\(session.browser) on \(session.os)"
            cell.sessionStartTime.text = session.creationDate.timeAgoSinceNow()
            cell.deleteButton.addTarget(self, action: #selector(deleteDevice(_:)), for: .touchUpInside)
        }
        return cell
    }


    // MARK: - Navigation
    /*
     override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
     if segue.identifier == "Add Session" {
     if let destination = (segue.destination.contents) as? QRViewController {
     destination.delegate = self
     }
     }
     }
     */

    //MARK: Actions

    func addSession(session: Session) {
        let newIndexPath = IndexPath(row: sessions.count, section: 0)
        sessions.append(session)
        tableView.insertRows(at: [newIndexPath], with: .automatic)
        if !sessions.isEmpty {
            DispatchQueue.main.async {
                self.noSessionsView.isHidden = true
            }
        }
    }

}


