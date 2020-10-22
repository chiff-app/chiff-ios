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
        selectedIndex = Properties.deniedPushNotifications || !Properties.firstPairingCompleted ? 1 : 0
        tabBar.items?[0].title = "tabs.accounts".localized
        tabBar.items?[1].title = "tabs.devices".localized
        tabBar.items?[2].title = "tabs.settings".localized
        tabBar.unselectedItemTintColor = UIColor.primaryHalfOpacity
        tabBar.tintColor = UIColor.primary
        launchTerms()
    }

    func setBadge(completed: Bool) {
        if let settingsItem = tabBar.items?[2] {
            settingsItem.badgeColor = UIColor.secondary
            settingsItem.badgeValue = !completed || Properties.isJailbroken ? "!" : nil
        }
    }

    func launchTerms() {
        if Properties.notifiedLatestTerms {
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            let alert = UIAlertController(title: "popups.questions.terms".localized, message: "popups.questions.updated_terms_message".localized, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "popups.responses.dont_care".localized, style: .cancel) { _ in
                Properties.notifiedLatestTerms = true
            })
            let agreeAction = UIAlertAction(title: "popups.responses.open".localized, style: .default, handler: { _ in
                let urlPath = Bundle.main.path(forResource: "terms_of_use", ofType: "md")
                self.performSegue(withIdentifier: "ShowTerms", sender: URL(fileURLWithPath: urlPath!))
                Properties.notifiedLatestTerms = true
            })
            alert.addAction(agreeAction)
            alert.preferredAction = agreeAction
            self.present(alert, animated: true, completion: nil)
        }
    }

    func handleQuestionnaireNotification(notification: Notification) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if let questionnaire = Questionnaire.all().first(where: { $0.shouldAsk() }) { self.presentQuestionAlert(questionnaire: questionnaire) }
        }
    }

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let destination = segue.destination.contents as? WebViewController, let url = sender as? URL {
            destination.presentedModally = true
            destination.url = url
        }
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
                Logger.shared.analytics(.questionnaireDeclined)
            }))
        }
        alert.addAction(UIAlertAction(title: "Remind me later", style: .default, handler: { _ in
            questionnaire.askAgainAt(date: Date(timeInterval: TimeInterval.ONE_DAY, since: Date()))
            questionnaire.save()
            Logger.shared.analytics(.questionnairePostponed)
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
