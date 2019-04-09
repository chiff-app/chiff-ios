/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit

class DevicesViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UIScrollViewDelegate, PairControllerDelegate {

    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var tableView: SelfSizingTableView!
    @IBOutlet weak var addSessionContainer: UIView!
    @IBOutlet weak var tableViewContainer: UIView!
    @IBOutlet weak var tabBarGradient: TabBarGradient!

    var sessions = [Session]()

    override func viewDidLoad() {
        super.viewDidLoad()

        let nc = NotificationCenter.default
        nc.addObserver(forName: .sessionStarted, object: nil, queue: OperationQueue.main, using: addSession)
        nc.addObserver(forName: .sessionEnded, object: nil, queue: OperationQueue.main, using: removeSession)

        scrollView.delegate = self
        tableView.dataSource = self
        tableView.delegate = self
        self.definesPresentationContext = true

        do {
            sessions = try Session.all()
        } catch {
            Logger.shared.error("Could not get sessions.", error: error)
        }
        updateUi()
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        (navigationController as? KeynNavigationController)?.moveAndResizeImage()
    }

    @IBAction func deleteDevice(_ sender: UIButton) {
        let buttonPosition = sender.convert(CGPoint(), to:tableView)
        if let indexPath = tableView.indexPathForRow(at:buttonPosition) {
            let session = sessions[indexPath.row]
            let alert = UIAlertController(title: "\("popups.responses.delete".localized) \(session.browser) on \(session.os)?", message: nil, preferredStyle: .actionSheet)
            alert.addAction(UIAlertAction(title: "popups.responses.cancel".localized, style: .cancel, handler: nil))
            alert.addAction(UIAlertAction(title: "popups.responses.delete".localized, style: .destructive, handler: { action in
                do {
                    try self.sessions[indexPath.row].delete(notifyExtension: true)
                    DispatchQueue.main.async {
                        self.sessions.remove(at: indexPath.row)
                        self.tableView.deleteRows(at: [indexPath], with: .automatic)
                        if self.sessions.isEmpty {
                            self.updateUi()
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
            DispatchQueue.main.async {
                self.sessions.remove(at: index)
                self.tableView.deleteRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
                if self.sessions.isEmpty {
                    self.updateUi()
                }
            }
        }
    }


    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sessions.count
    }


    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "DeviceCell", for: indexPath)
        if let cell = cell as? DevicesViewCell {
            let session = sessions[indexPath.row]
            cell.titleLabel.text = "\(session.browser) on \(session.os)"
            cell.timestampLabel.text = session.creationDate.timeAgoSinceNow()
            cell.deviceLogo.image = UIImage(named: session.browser)
//            cell.deleteButton.addTarget(self, action: #selector(deleteDevice(_:)), for: .touchUpInside)
        }
        return cell
    }


    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        print(indexPath)
    }
    
    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let destination = segue.destination.contents as? PairContainerViewController {
            destination.pairControllerDelegate = self
        }
    }

    // MARK: - Actions

    func addSession(notification: Notification) {
        guard let session = notification.userInfo?["session"] as? Session else {
            Logger.shared.warning("Session was nil when trying to add it to the devices view.")
            return
        }
        DispatchQueue.main.async {
            self.sessionCreated(session: session)
        }
    }

    // MARK: - PairControllerDelegate

    func sessionCreated(session: Session) {
        dismiss(animated: true, completion: nil)
        let newIndexPath = IndexPath(row: sessions.count, section: 0)
        sessions.append(session)
        tableView.insertRows(at: [newIndexPath], with: .automatic)
        updateUi()
    }

    func prepareForPairing(completionHandler: @escaping (_ result: Bool) -> Void) {
        completionHandler(true)
    }

    // MARK: - Private functions

    private func updateUi() {
        if !sessions.isEmpty {
            addSessionContainer.isHidden = true
            tableViewContainer.isHidden = false
            tabBarGradient.isHidden = false
            view.backgroundColor = UIColor.primaryVeryLight
            addAddButton()
        } else {
            addSessionContainer.isHidden = false
            tableViewContainer.isHidden = true
            tabBarGradient.isHidden = true
            view.backgroundColor = UIColor.white
            navigationItem.rightBarButtonItem = nil
        }
    }

    private func addAddButton(){
        guard self.navigationItem.rightBarButtonItem == nil else {
            return
        }

        let button = KeynBarButton(frame: CGRect(x: 0, y: 0, width: 40, height: 40))
        button.setImage(UIImage(named:"add_button"), for: .normal)
        button.addTarget(self, action: #selector(showAddSession), for: .touchUpInside)
        self.navigationItem.rightBarButtonItem = button.barButtonItem
    }

    @objc private func showAddSession() {
        performSegue(withIdentifier: "ShowAddSession", sender: self)
    }
}
