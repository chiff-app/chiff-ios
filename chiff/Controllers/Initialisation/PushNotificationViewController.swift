//
//  PushNotificationViewController.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import UIKit
import PromiseKit
import ChiffCore

class PushNotificationViewController: UIViewController {

    let notificationMessages = [
        ("notifications.onboarding_reminder_title.first".localized, "notifications.onboarding_reminder_message.first".localized),
        ("notifications.onboarding_reminder_title.second".localized, "notifications.onboarding_reminder_message.second".localized),
        ("notifications.onboarding_reminder_title.third".localized, "notifications.onboarding_reminder_message.third".localized)
    ]

    // MARK: - Actions

    @IBAction func enablePushNotifications(_ sender: UIButton) {
        firstly {
            PushNotifications.requestAuthorization()
        }.done { result in
            if result {
                self.registerForPushNotifications()
                self.scheduleNudgeNotifications()
            } else {
                self.performSegue(withIdentifier: "ShowLoggingPreferences", sender: self)
            }
        }
    }

    @IBAction func nextScreen(_ sender: UIButton) {
        Properties.deniedPushNotifications = true
        self.performSegue(withIdentifier: "ShowLoggingPreferences", sender: self)
    }

    // MARK: - Private functions

    private func registerForPushNotifications() {
        firstly {
            PushNotifications.register()
        }.done(on: .main) { result in
            if result {
                self.performSegue(withIdentifier: "ShowPairingExplanation", sender: self)
            } else {
                self.performSegue(withIdentifier: "ShowLoggingPreferences", sender: self)
            }
        }
    }

    private func scheduleNudgeNotifications() {
        if Properties.firstPairingCompleted { return }
        let now = Date()
        let calendar = Calendar.current
        let askInEvening = calendar.dateComponents([.hour], from: now).hour! < 18
        scheduleNotification(id: 0, askInEvening: askInEvening, day: nil)
        scheduleNotification(id: 1, askInEvening: !askInEvening, day: 3)
        scheduleNotification(id: 2, askInEvening: askInEvening, day: 7)
    }

    private func scheduleNotification(id: Int, askInEvening: Bool, day: Int?) {
        let content = UNMutableNotificationContent()
        (content.title, content.body) = notificationMessages[id]
        content.categoryIdentifier = NotificationCategory.onboardingNudge

        var date: DateComponents!
        if let day = day {
            let calendar = Calendar.current
            let now = Date()
            date = calendar.dateComponents([.day, .month, .year], from: now, to: calendar.date(byAdding: .day, value: day, to: now)!)
        } else {
            date = DateComponents()
        }

        // 1600 or 2030
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
