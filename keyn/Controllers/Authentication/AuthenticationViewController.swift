/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit

class AuthenticationViewController: UIViewController {
    @IBOutlet var passcodeButtons: [UIButton]!
    @IBOutlet weak var deleteButton: UIButton!
    @IBOutlet weak var touchIDButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        drawButtons()
    }

    // MARK: - Actions
    
    @IBAction func touchID(_ sender: UIButton) {
        AuthenticationGuard.shared.authenticateUser(cancelChecks: false)
    }

    // MARK: - Private
    
    private func drawButtons() {
        touchIDButton.imageView!.contentMode = .scaleAspectFit
        touchIDButton.imageEdgeInsets = UIEdgeInsets.init(top: 13, left: 13, bottom: 13, right: 13)

        for button in passcodeButtons {
            button.layer.borderWidth = 1.3
            button.layer.borderColor = UIColor.white.cgColor
            button.layer.cornerRadius = button.frame.width/2
        }
    }
}
