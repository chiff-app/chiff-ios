/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit

class RootViewController: UITabBarController {

    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: OperationQueue.main, using: handleQuestionnaireNotification)
        setBadge(completed: Seed.paperBackupCompleted)
        selectedIndex = Properties.deniedPushNotifications ? 1 : 0
    }

    func setBadge(completed: Bool) {
        if let settingsItem = tabBar.items?[2] {
            settingsItem.badgeColor = UIColor.secondary
            settingsItem.badgeValue = completed ? nil : "!"
        }
    }

    func handleQuestionnaireNotification(notification: Notification) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if let questionnaire = Questionnaire.all().first(where: { $0.shouldAsk() })
            { self.presentQuestionAlert(questionnaire: questionnaire) }
        }
    }

    func showGradient(_ value: Bool) {
        (tabBar as! KeynTabBar).gradientView.isHidden = !value
    }
    
    // MARK: - Private functions

    private func presentQuestionAlert(questionnaire: Questionnaire) {
        let alert = UIAlertController(title: "popups.questions.questionnaire_popup_title".localized, message: "popups.questions.questionnaire_permission".localized, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "\("popups.responses.yes".localized.capitalizedFirstLetter)!", style: .default, handler: { _ in
            self.launchQuestionnaire(questionnaire: questionnaire)
        }))
        if !questionnaire.compulsory {
            alert.addAction(UIAlertAction(title: "popups.responses.questionnaire_deny".localized, style: .cancel, handler: { _ in
                questionnaire.isFinished = true
                questionnaire.save()
                Logger.shared.analytics("Declined questionnaire.", code: .declinedQuestionnaire)
            }))
        }
        alert.addAction(UIAlertAction(title: "Remind me later", style: .default, handler: { _ in
            questionnaire.askAgainAt(date: Date(timeInterval: TimeInterval.ONE_DAY, since: Date()))
            questionnaire.save()
            Logger.shared.analytics("Postponed questionnaire.", code: .postponedQuestionnaire)
        }))
        self.present(alert, animated: true, completion: nil)
    }    
    
    private func launchQuestionnaire(questionnaire: Questionnaire) {
        let storyboard: UIStoryboard = UIStoryboard.get(.feedback)
        guard let modalViewController = storyboard.instantiateViewController(withIdentifier: "QuestionnaireController") as? QuestionnaireController else {
            Logger.shared.error("ViewController has wrong type.")
            return
        }
        modalViewController.questionnaire = questionnaire
        modalViewController.modalPresentationStyle = .fullScreen
        self.present(modalViewController, animated: true, completion: nil)
    }

}
