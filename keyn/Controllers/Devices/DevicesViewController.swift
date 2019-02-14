/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit

protocol canReceiveSession {
    func addSession(session: Session)
}

class DevicesViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, canReceiveSession {
    @IBOutlet weak var tableView: UITableView!
    
    private let DEVICE_ROW_HEIGHT: CGFloat = 90
    
    var sessions = [Session]()

    override func viewDidLoad() {
        super.viewDidLoad()

        let nc = NotificationCenter.default
        nc.addObserver(forName: .sessionStarted, object: nil, queue: OperationQueue.main, using: addSession)
        nc.addObserver(forName: .sessionEnded, object: nil, queue: OperationQueue.main, using: removeSession)

        do {
            if let storedSessions = try Session.all() {
                sessions = storedSessions
            }
        } catch {
            Logger.shared.error("Could not get sessions.", error: error)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let selectedIndexPath = tableView.indexPathForSelectedRow {
            tableView.deselectRow(at: selectedIndexPath, animated: true)
        }
    }

    // TODO: Frank: wat zijn die nummers?
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch indexPath.section {
        case 0:
            return DEVICE_ROW_HEIGHT
        case 1:
            return UITableViewCell.defaultHeight
        default:
            assert(false, "section \(indexPath.section)")
            // Dummy code for archive compiler
            return UITableViewCell.defaultHeight
        }
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch section {
        case 0:
            return nil
        case 1:
            return "pairing_instruction".localized
        default:
            assert(false, "section \(section)")
            return nil
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return "devices".localized
        case 1:
            return nil
        default:
            assert(false, "section \(section)")
            // Dummy code for archive compiler
            return nil
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
            // Dummy code for archive compiler
            return 1
        }
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    @objc func deleteDevice(_ sender: UIButton) {
        let buttonPosition = sender.convert(CGPoint(), to:tableView)
        if let indexPath = tableView.indexPathForRow(at:buttonPosition) {
            let session = sessions[indexPath.row]
            let alert = UIAlertController(title: "\("delete".localized) \(session.browser) on \(session.os)?", message: nil, preferredStyle: .actionSheet)
            alert.addAction(UIAlertAction(title: "cancel".localized, style: .cancel, handler: nil))
            alert.addAction(UIAlertAction(title: "delete".localized, style: .destructive, handler: { action in
                do {
                    try self.sessions[indexPath.row].delete(includingQueue: true)
                    self.sessions.remove(at: indexPath.row)
                    self.tableView.deleteRows(at: [indexPath], with: .automatic)
                    if self.sessions.isEmpty {
                        DispatchQueue.main.async {
                            let pairViewController = self.storyboard?.instantiateViewController(withIdentifier: "Pair Controller")
                            self.navigationController?.setViewControllers([pairViewController!], animated: false)
                        }
                    }
                } catch {
                    Logger.shared.error("Could not delete session.", error: error)
                }
            }))
            self.present(alert, animated: true, completion: nil)
        }
    }

    func removeSession(_ notification: Notification) {
        guard let sessionID = notification.userInfo?["sessionID"] as? String else {
            Logger.shared.warning("Userinfo was nil when trying to remove session from view.")
            return
        }

        if let index = sessions.index(where: { sessionID == $0.id }) {
            sessions.remove(at: index)
            tableView.deleteRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
            if self.sessions.isEmpty {
                DispatchQueue.main.async {
                    let pairViewController = self.storyboard?.instantiateViewController(withIdentifier: "Pair Controller")
                    self.navigationController?.setViewControllers([pairViewController!], animated: false)
                }
            }
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
                cell.deviceLogo.image = UIImage(named: session.browser)
                cell.deleteButton.addTarget(self, action: #selector(deleteDevice(_:)), for: .touchUpInside)
            }
            return cell
        case 1:
            let cell = tableView.dequeueReusableCell(withIdentifier: "Scan QR", for: indexPath)
            cell.textLabel?.text = "scan_qr".localized
            return cell
        default:
            assert(false, "section \(indexPath.section)")
            // Dummy code for archive compiler
            let cell = tableView.dequeueReusableCell(withIdentifier: "Device Cell", for: indexPath)
            return cell
        }
    }
    
    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "Add Session", let destination = segue.destination.contents as? PairViewController {
            destination.devicesDelegate = self
        }
    }

    // MARK: - Actions

    func addSession(notification: Notification) {
        guard let session = notification.userInfo?["session"] as? Session else {
            Logger.shared.warning("Session was nil when trying to add it to the devices view.")
            return
        }
        addSession(session: session)
    }

    func addSession(session: Session) {
        let newIndexPath = IndexPath(row: sessions.count, section: 0)
        sessions.append(session)
        tableView.insertRows(at: [newIndexPath], with: .automatic)
    }
}
