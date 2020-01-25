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
    @IBOutlet weak var pushNotificationWarning: UIView!

    var sessions = [Session]()

    override func viewDidLoad() {
        super.viewDidLoad()

        let nc = NotificationCenter.default
        nc.addObserver(forName: .sessionStarted, object: nil, queue: OperationQueue.main, using: addSession)
        nc.addObserver(forName: .sessionEnded, object: nil, queue: OperationQueue.main, using: removeSession)
        nc.addObserver(forName: .sessionUpdated, object: nil, queue: OperationQueue.main, using: reloadData)
        nc.addObserver(forName: .notificationSettingsUpdated, object: nil, queue: OperationQueue.main) { (notification) in
            DispatchQueue.main.async {
                self.updateUi()
            }
        }

        scrollView.delegate = self
        tableView.dataSource = self
        tableView.delegate = self
        self.definesPresentationContext = true

        do {
            sessions = try BrowserSession.all()
            sessions.append(contentsOf: try TeamSession.all())
        } catch {
            Logger.shared.error("Could not get sessions.", error: error)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateUi()
    }

    @IBAction func deleteDevice(_ sender: UIButton) {
        let buttonPosition = sender.convert(CGPoint(), to:tableView)
        if let indexPath = tableView.indexPathForRow(at:buttonPosition) {
            let session = sessions[indexPath.row]
            let alert = UIAlertController(title: "\("popups.responses.delete".localized) \(session.title)?", message: nil, preferredStyle: .actionSheet)
            alert.addAction(UIAlertAction(title: "popups.responses.cancel".localized, style: .cancel, handler: nil))
            alert.addAction(UIAlertAction(title: "popups.responses.delete".localized, style: .destructive, handler: { action in
                self.sessions[indexPath.row].delete(notify: true) { result in
                    DispatchQueue.main.async {
                        if case .failure(let error) = result {
                            Logger.shared.error("Could not delete session.", error: error)
                            self.showAlert(message: "errors.session_delete".localized)
                        } else {
                            self.sessions.remove(at: indexPath.row)
                            self.tableView.deleteRows(at: [indexPath], with: .automatic)
                            if self.sessions.isEmpty {
                                self.updateUi()
                            }
                        }
                    }
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

        if let index = sessions.firstIndex(where: { sessionID == $0.id }) {
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
        return tableView.dequeueReusableCell(withIdentifier: "DeviceCell", for: indexPath)
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let session = sessions[indexPath.row]
        if let cell = cell as? DevicesViewCell {
            cell.titleLabel.text = session.title
            cell.timestampLabel.text = session.creationDate.timeAgoSinceNow()
            cell.deviceLogo.image = session.logo ?? UIImage(named: "logo_purple")
        } else {
            Logger.shared.warning("Unknown browser")
        }
    }
    
    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let destination = segue.destination.contents as? PairContainerViewController {
            destination.pairControllerDelegate = self
        } else if let destination = segue.destination.contents as? SessionDetailViewController {
            guard let cell = sender as? UITableViewCell, let indexPath = tableView.indexPath(for: cell) else { fatalError() }
            destination.session = sessions[indexPath.row]
        }
    }

    // MARK: - Actions

    func addSession(notification: Notification) {
        guard let session = notification.userInfo?["session"] as? BrowserSession else {
            Logger.shared.warning("Session was nil when trying to add it to the devices view.")
            return
        }
        DispatchQueue.main.async {
            self.sessionCreated(session: session)
        }
    }

    @IBAction func openSettings(_ sender: UIButton) {
        if let url = URL.init(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }

    @IBAction func unwindToDevicesOverview(sender: UIStoryboardSegue) {
        guard let sourceViewController = sender.source as? SessionDetailViewController, var session = sourceViewController.session, let index = self.sessions.firstIndex(where: { session.id == $0.id }) else {
            return
        }
        if sender.identifier == "DeleteSession" {
            session.delete(notify: true) { result in
                DispatchQueue.main.async {
                    if case .failure(let error) = result {
                        Logger.shared.error("Could not delete session.", error: error)
                        self.showAlert(message: "errors.session_delete".localized)
                    } else {
                        let indexPath = IndexPath(row: index, section: 0)
                        self.sessions.remove(at: indexPath.row)
                        self.tableView.deleteRows(at: [indexPath], with: .automatic)
                        if self.sessions.isEmpty {
                            self.updateUi()
                        }
                    }
                }
            }
        } else if sender.identifier == "UpdateSession", let title = sourceViewController.sessionNameTextField.text {
            session.title = title
            try? session.update()
            sessions[index] = session
            tableView.reloadData()
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

    // MARK: - Private functions

    private func reloadData(notification: Notification) {
        guard let session = notification.userInfo?["session"] as? Session, let index = self.sessions.firstIndex(where: { session.id == $0.id }) else {
            return
        }
        sessions[index] = session
        tableView.reloadData()
    }

    private func updateUi() {
        guard !Properties.deniedPushNotifications else {
            pushNotificationWarning.isHidden = false
            navigationItem.rightBarButtonItem = nil
            return
        }
        pushNotificationWarning.isHidden = true
        if !sessions.isEmpty {
            addSessionContainer.isHidden = true
            tableViewContainer.isHidden = false
            addAddButton()
        } else {
            addSessionContainer.isHidden = false
            tableViewContainer.isHidden = true
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
        Logger.shared.analytics(.addSessionOpened)
    }
}
