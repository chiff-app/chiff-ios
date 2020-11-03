/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit
import PromiseKit

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
        nc.addObserver(self, selector: #selector(addSession(_:)), name: .sessionStarted, object: nil)
        nc.addObserver(self, selector: #selector(removeSession(_:)), name: .sessionEnded, object: nil)
        nc.addObserver(self, selector: #selector(reloadData(_:)), name: .sessionUpdated, object: nil)
        nc.addObserver(self, selector: #selector(updateUi), name: .notificationSettingsUpdated, object: nil)

        scrollView.delegate = self
        tableView.dataSource = self
        tableView.delegate = self
        self.definesPresentationContext = true

        do {
            var sessions: [Session] = try BrowserSession.all()
            sessions.append(contentsOf: try TeamSession.all())
            self.sessions = sessions.sorted(by: { $0.creationDate < $1.creationDate })
        } catch {
            Logger.shared.error("Could not get sessions.", error: error)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateUi()
    }

    @IBAction func deleteDevice(_ sender: UIButton) {
        let buttonPosition = sender.convert(CGPoint(), to: tableView)
        if let indexPath = tableView.indexPathForRow(at: buttonPosition) {
            let session = sessions[indexPath.row]
            let alert = UIAlertController(title: "\("popups.responses.delete".localized) \(session.title)?", message: nil, preferredStyle: .actionSheet)
            alert.addAction(UIAlertAction(title: "popups.responses.cancel".localized, style: .cancel, handler: nil))
            alert.addAction(UIAlertAction(title: "popups.responses.delete".localized, style: .destructive, handler: { _ in
                self.deleteSession(session: self.sessions[indexPath.row], indexPath: indexPath)
            }))
            self.present(alert, animated: true, completion: nil)
        }
    }

    @objc func removeSession(_ notification: Notification) {
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

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        let session = sessions[indexPath.row]
        if session is BrowserSession {
            return true
        } else if let session = session as? TeamSession, !session.isAdmin {
            return true
        }
        return false
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        let session = sessions[indexPath.row]
        if session is BrowserSession {
            deleteSession(at: indexPath)
        } else if let session = session as? TeamSession, !session.isAdmin {
            deleteSession(at: indexPath)
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

    func deleteSession(at indexPath: IndexPath) {
        let session = sessions[indexPath.row]
        let alert = UIAlertController(title: "\("popups.responses.delete".localized) \(session.title)?", message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "popups.responses.cancel".localized, style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "popups.responses.delete".localized, style: .destructive, handler: { _ in
            self.deleteSession(session: session, indexPath: indexPath)
        }))
        self.present(alert, animated: true, completion: nil)
    }

    @objc func addSession(_ notification: Notification) {
        guard let session = notification.userInfo?["session"] as? Session else {
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
        guard let sourceViewController = sender.source as? SessionDetailViewController,
            var session = sourceViewController.session,
            let index = self.sessions.firstIndex(where: { session.id == $0.id }) else {
            return
        }
        if sender.identifier == "DeleteSession" {
            deleteSession(session: session, indexPath: IndexPath(row: index, section: 0))
        } else if sender.identifier == "UpdateSession", let title = sourceViewController.sessionNameTextField.text {
            session.title = title
            try? session.update(makeBackup: true)
            sessions[index] = session
            tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .none)
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

    @objc private func reloadData(_ notification: Notification) {
        if let session = notification.userInfo?["session"] as? Session,
            let index = self.sessions.firstIndex(where: { session.id == $0.id }) {
            sessions[index] = session
            tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
        } else {
            do {
                var sessions: [Session] = try BrowserSession.all()
                sessions.append(contentsOf: try TeamSession.all())
                self.sessions = sessions.sorted(by: { $0.creationDate < $1.creationDate })
                tableView.reloadData()
            } catch {
                Logger.shared.error("Could not get sessions.", error: error)
            }
        }
    }

    @objc private func updateUi() {
        DispatchQueue.main.async { [weak self] in
            guard !Properties.deniedPushNotifications else {
                self?.pushNotificationWarning.isHidden = false
                self?.navigationItem.rightBarButtonItem = nil
                return
            }
            self?.pushNotificationWarning.isHidden = true
            if !(self?.sessions.isEmpty ?? false) {
                self?.addSessionContainer.isHidden = true
                self?.tableViewContainer.isHidden = false
                self?.addAddButton()
            } else {
                self?.addSessionContainer.isHidden = false
                self?.tableViewContainer.isHidden = true
                self?.navigationItem.rightBarButtonItem = nil
            }
        }

    }

    private func addAddButton() {
        guard self.navigationItem.rightBarButtonItem == nil else {
            return
        }

        let button = KeynBarButton(frame: CGRect(x: 0, y: 0, width: 30, height: 30))
        button.setImage(UIImage(named: "add_button"), for: .normal)
        button.addTarget(self, action: #selector(showAddSession), for: .touchUpInside)
        self.navigationItem.rightBarButtonItem = button.barButtonItem
    }

    @objc private func showAddSession() {
        performSegue(withIdentifier: "ShowAddSession", sender: self)
        Logger.shared.analytics(.addSessionOpened)
    }

    private func deleteSession(session: Session, indexPath: IndexPath) {
        if let session = session as? TeamSession, session.isAdmin {
            self.showAlert(message: "errors.session_delete".localized)
        }
        firstly {
            session.delete(notify: true)
        }.done(on: .main) {
            self.sessions.remove(at: indexPath.row)
            self.tableView.deleteRows(at: [indexPath], with: .automatic)
            if self.sessions.isEmpty {
                self.updateUi()
            }
        }.catch(on: .main) { error in
            Logger.shared.error("Could not delete session.", error: error)
            self.showAlert(message: "errors.session_delete".localized)
        }
    }
}
