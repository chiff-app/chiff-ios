//
//  DevicesTableViewController.swift
//  athena
//
//  Created by Bas Doorn on 04/11/2017.
//  Copyright © 2017 athena. All rights reserved.
//

import UIKit

class DevicesTableViewController: UITableViewController, isAbleToReceiveData {
    
    var sessions = [Session]()

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // TODO: Can this be implemented more smoothly, e.g. not with segue?
        if sessions.count == 0 {
            performSegue(withIdentifier: "First Session", sender: self)
        }
    }

    // MARK: - Table view data source

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sessions.count
    }
        
    override func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        sessions.remove(at: indexPath.row)
        tableView.deleteRows(at: [indexPath], with: .automatic)
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Device Cell", for: indexPath)
        if let cell = cell as? DeviceTableViewCell {
            let session = sessions[indexPath.row]
            cell.deviceName.text = session.name
            cell.sessionStartTime.text = session.URL
            // TODO: Add delete button
        }
        return cell
    }

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */

    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
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
    
    
    //MARK: Actions
    
    func addSession(session: Session) {
        let newIndexPath = IndexPath(row: sessions.count, section: 0)
        
        sessions.append(session)
        tableView.insertRows(at: [newIndexPath], with: .automatic)
    }

}

// TODO: Where should this protocol be defined?
protocol isAbleToReceiveData {
    func addSession(session: Session)
}

// TODO: Temporary Session struct that parses prototype QR JSON objects
struct Session: Codable {
    let name: String
    let URL: String
}
