import UIKit

protocol isAbleToReceiveData {
    func addSession(session: Session)
}

class DevicesTableViewController: UITableViewController, isAbleToReceiveData {
    
    var sessions = [Session]()

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        goToQrScannerIfEmpty()
    }

    // MARK: - Table view data source

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sessions.count
    }
    
    @objc func deleteDevice(_ sender: UIButton) {
        let buttonPosition = sender.convert(CGPoint(), to:tableView)
        if let indexPath = tableView.indexPathForRow(at:buttonPosition) {
            sessions.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .automatic)
        }
        goToQrScannerIfEmpty()
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Device Cell", for: indexPath)
        if let cell = cell as? DeviceTableViewCell {
            let session = sessions[indexPath.row]
            cell.deviceName.text = session.name
            cell.sessionStartTime.text = session.URL
            cell.deleteButton.addTarget(self, action: #selector(deleteDevice(_:)), for: .touchUpInside)
        }
        return cell
    }


    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "Add Session" {
            if let destination = (segue.destination.contents) as? QRViewController {
                destination.delegate = self
            }
        } else if segue.identifier == "First Session" {
            if let destination = (segue.destination.contents) as? QRViewController {
                destination.isFirstSession = true
                destination.navigationItem.leftBarButtonItem?.isEnabled = false
                destination.navigationItem.leftBarButtonItem?.tintColor = UIColor.clear
                destination.delegate = self
            }
        }
    }
    
    private func goToQrScannerIfEmpty() {
        guard sessions.count == tableView.numberOfRows(inSection: 0) else {
            fatalError("Inconsistency between data model and tableView.")
        }
        
        // TODO: Can this be implemented more smoothly, e.g. not with segue?
        if sessions.count == 0 {
            performSegue(withIdentifier: "First Session", sender: self)
        }
    }
    
    
    //MARK: Actions
    
    func addSession(session: Session) {
        let newIndexPath = IndexPath(row: sessions.count, section: 0)
        sessions.append(session)
        tableView.insertRows(at: [newIndexPath], with: .automatic)
    }

}


// TODO: Temporary Session struct that parses prototype QR JSON objects
struct Session: Codable {
    let name: String
    let URL: String
}
