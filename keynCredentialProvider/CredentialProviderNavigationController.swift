//
//  CredentialProviderNavigationController.swift
//  keynCredentialProvider
//
//  Created by Bas Doorn on 11/09/2018.
//  Copyright © 2018 keyn. All rights reserved.
//

import UIKit
import AuthenticationServices

class CredentialProviderNavigationController: UINavigationController {
    
    var passedExtensionContext: ASCredentialProviderExtensionContext!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
}
