//
//  BackupWizardViewController.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import UIKit

class BackupWizardViewController: UIViewController {

    @IBOutlet weak var wordLabel: UILabel!
    @IBOutlet weak var previousButton: UIButton!
    @IBOutlet weak var counterLabel: UILabel!
    @IBOutlet weak var backupCircle: BackupCircle!

    var mnemonic: [String]!
    var counter: Int = 0 {
        didSet {
            counterLabel.text = "\(counter + 1) / \(mnemonic!.count)"
            backupCircle.animateCircle(from: CGFloat(oldValue + 1) / CGFloat(mnemonic.count), to: CGFloat(counter + 1) / CGFloat(mnemonic.count))
        }
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        wordLabel.text = mnemonic[counter]
        counterLabel.text = "\(counter + 1) / \(mnemonic.count)"
        navigationItem.leftBarButtonItem?.setColor(color: .white)
        Logger.shared.analytics(.backupProcessStarted)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        backupCircle.draw(color: UIColor.white.cgColor, backgroundColor: UIColor(red: 1, green: 1, blue: 1, alpha: 0.1).cgColor, initialPosition: 1.0 / 12)
    }

    // MARK: - Actions

    @IBAction func next(_ sender: UIButton) {
        if counter < mnemonic!.count - 1 {
            counter += 1
            wordLabel.text = mnemonic![counter]
            if counter >= 1 {
                previousButton.isEnabled = true
                previousButton.alpha = 1.0
            }
        } else {
           performSegue(withIdentifier: "MnemonicCheck", sender: self)
        }
    }

    @IBAction func previous(_ sender: UIButton) {
        if counter > 0 {
            counter -= 1
            wordLabel.text = mnemonic![counter]
            if counter <= 0 {
                previousButton.isEnabled = false
                previousButton.alpha = 0.5
            }
        }
    }

    @IBAction func cancel(_ sender: UIBarButtonItem) {
        let alert = UIAlertController(title: "\("popups.questions.cancel_backup".localized.capitalizedFirstLetter)",
                                      message: "popups.questions.cancel_backup_description".localized,
                                      preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "popups.responses.continue".localized.capitalizedFirstLetter,
                                      style: .cancel,
                                      handler: nil))
        alert.addAction(UIAlertAction(title: "popups.responses.cancel".localized.capitalizedFirstLetter,
                                      style: .destructive,
                                      handler: { _ in
            self.performSegue(withIdentifier: "UnwindToSettings", sender: self)
        }))
        self.present(alert, animated: true, completion: nil)
    }

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let destination = segue.destination as? BackupCheckViewController {
            destination.mnemonic = mnemonic
        }
    }

}
