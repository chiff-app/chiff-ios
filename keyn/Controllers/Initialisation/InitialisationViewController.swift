/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit
import LocalAuthentication

class InitialisationViewController: UIViewController {

    let notificationMessages = [
        "notifications.onboarding_reminder_message.first".localized,
        "notifications.onboarding_reminder_message.second".localized,
        "notifications.onboarding_reminder_message.third".localized
    ]

    @IBOutlet weak var loadingView: UIView!

    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationManager.shared.requestAuthorization() { result in
            if result {
                self.scheduleNudgeNotifications()
            }
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(true)
        self.loadingView.isHidden = true
    }

    // MARK: - Actions

    @IBAction func trySetupKeyn(_ sender: Any) {
        if Properties.agreedWithTerms {
            setupKeyn()
        } else {
            performSegue(withIdentifier: "ShowTerms", sender: self)
        }
    }

    @IBAction func unwindAndSetupKeyn(sender: UIStoryboardSegue) {
        Properties.agreedWithTerms = true
        setupKeyn()
    }

    // MARK: - Private functions

    private func setupKeyn() {
        loadingView.isHidden = false
        if Seed.hasKeys && BackupManager.shared.hasKeys {
            registerForPushNotifications()
        } else {
            initializeSeed { (result) in
                DispatchQueue.main.async {
                    switch result {
                    case .success(_):
                        self.registerForPushNotifications()
                        Logger.shared.analytics(.seedCreated, override: true)
                    case .failure(let error):
                        if let error = error as? LAError {
                            if let errorMessage = LocalAuthenticationManager.shared.handleError(error: error) {
                                self.loadingView.isHidden = true
                                self.showError(message:"\("errors.seed_creation".localized): \(errorMessage)")
                            }
                        } else {
                            self.loadingView.isHidden = true
                            self.showError(message: error.localizedDescription, title: "errors.seed_creation".localized)
                        }
                    }
                }
            }
        }
    }

    private func registerForPushNotifications() {
        NotificationManager.shared.registerForPushNotifications() { result in
            DispatchQueue.main.async {
                if result {
                    self.performSegue(withIdentifier: "ShowPairingExplanation", sender: self)
                } else {
                    // TODO: Present warning vc, then continue to showRootVC
                    self.showRootController()
                }
            }
        }
    }

    private func initializeSeed(completionHandler: @escaping (Result<Void, Error>) -> Void) {
        LocalAuthenticationManager.shared.authenticate(reason: "initialization.initialize_keyn".localized, withMainContext: true) { (result) in
            switch result {
            case .success(let context): Seed.create(context: context, completionHandler: completionHandler)
            case .failure(let error): completionHandler(.failure(error))
            }
        }
    }

    private func showRootController() {
        guard let window = UIApplication.shared.keyWindow else {
            return
        }
        guard let vc = UIStoryboard.main.instantiateViewController(withIdentifier: "RootController") as? RootViewController else {
            Logger.shared.error("Unexpected root view controller type")
            fatalError("Unexpected root view controller type")
        }
        UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve, animations: {
            DispatchQueue.main.async {
                window.rootViewController = vc
            }
        })
    }

    private func scheduleNudgeNotifications() {
        let now = Date()
        let calendar = Calendar.current
        let askInEvening = calendar.date(bySettingHour: 16, minute: 0, second: 0, of: now)! < now
        scheduleNotification(id: 0, askInEvening: askInEvening, body: notificationMessages[0], day: nil)
        scheduleNotification(id: 1, askInEvening: !askInEvening, body: notificationMessages[1], day: 4)
        scheduleNotification(id: 2, askInEvening: askInEvening, body: notificationMessages[2], day: 7)
    }

    private func scheduleNotification(id: Int, askInEvening: Bool, body: String, day: Int?) {
        let content = UNMutableNotificationContent()
        content.body = body
        content.categoryIdentifier = NotificationCategory.ONBOARDING_NUDGE

        var date: DateComponents!
        if let day = day {
            let calendar = Calendar.current
            let now = Date()
            date = calendar.dateComponents([.day, .month, .year], from: now, to: calendar.date(byAdding: .day, value: day, to: now)!)
        } else {
            date = DateComponents()
        }
        date.hour = askInEvening ? 20 : 16
        date.minute = askInEvening ? 30 : 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: false)
        let request = UNNotificationRequest(identifier: Properties.nudgeNotificationIdentifiers[id], content: content, trigger: trigger)

        // Schedule the request with the system.
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.add(request) { (error) in
            if let error = error {
                Logger.shared.error("Error scheduling notification", error: error)
            }
        }
    }

}
