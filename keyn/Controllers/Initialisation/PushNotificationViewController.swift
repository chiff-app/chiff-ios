//
//  PushNotificationViewController.swift
//  keyn
//
//  Created by Bas Doorn on 05/12/2019.
//  Copyright © 2019 keyn. All rights reserved.
//

import UIKit

class PushNotificationViewController: UIViewController {

    let notificationMessages = [
        ("notifications.onboarding_reminder_title.first".localized, "notifications.onboarding_reminder_message.first".localized),
        ("notifications.onboarding_reminder_title.second".localized, "notifications.onboarding_reminder_message.second".localized),
        ("notifications.onboarding_reminder_title.third".localized, "notifications.onboarding_reminder_message.third".localized)
    ]


    @IBAction func enablePushNotifications(_ sender: UIButton) {
        PushNotifications.requestAuthorization() { result in
            if result {
                self.registerForPushNotifications()
                self.scheduleNudgeNotifications()
            }
        }
    }

    private func registerForPushNotifications() {
        PushNotifications.register() { result in
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
        content.categoryIdentifier = NotificationCategory.ONBOARDING_NUDGE

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
