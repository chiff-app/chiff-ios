//
//  AuthenticationGuard.swift
//  keyn
//
//  Created by bas on 17/04/2018.
//  Copyright © 2018 keyn. All rights reserved.
//

import UIKit
import LocalAuthentication
import JustLog

class AuthenticationGuard {
    
    static let sharedInstance = AuthenticationGuard()
    private let lockWindow: UIWindow
    private let lockViewTag = 390847239047
    var authorizationInProgress = false
    var authenticationInProgress = false
    
    private init() {
        lockWindow = UIWindow(frame: UIScreen.main.bounds)
        lockWindow.windowLevel = UIWindowLevelAlert
        lockWindow.screen = UIScreen.main
        
        let storyboard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
        lockWindow.rootViewController = storyboard.instantiateViewController(withIdentifier: "LoginController") as! LoginViewController
        
        let nc = NotificationCenter.default
        nc.addObserver(forName: NSNotification.Name.UIApplicationDidEnterBackground, object: nil, queue: OperationQueue.main, using: applicationDidEnterBackground)
        nc.addObserver(forName: NSNotification.Name.UIApplicationDidFinishLaunching, object: nil, queue: OperationQueue.main, using: didFinishLaunchingWithOptions)
        nc.addObserver(forName: NSNotification.Name.UIApplicationWillEnterForeground, object: nil, queue: OperationQueue.main, using: applicationWillEnterForeground)
        nc.addObserver(forName: NSNotification.Name.UIApplicationDidBecomeActive, object: nil, queue: OperationQueue.main, using: applicationDidBecomeActive)
    }
    
    func hideLockWindow() {
        UIView.animate(withDuration: 0.25, animations: {
            self.lockWindow.alpha = 0.0
        }) { if $0 {
            self.lockWindow.isHidden = true
            self.lockWindow.alpha = 1.0
            self.authenticationInProgress = false
            }
        }
    }
    
    // MARK: UIApplication Notification Handlers
    
    private func applicationWillEnterForeground(notification: Notification) {
        if let lockView = lockWindow.viewWithTag(lockViewTag) {
            lockView.removeFromSuperview()
        }
    }
    
    private func applicationDidBecomeActive(notification: Notification) {
        if let lockView = lockWindow.viewWithTag(lockViewTag) {
            lockView.removeFromSuperview()
        }
        authenticateUser(cancelChecks: true)
    }
    
    private func applicationDidEnterBackground(notification: Notification) {
        if Seed.exists() {
            lockWindow.makeKeyAndVisible()
        }
        authenticationInProgress = false
        authorizationInProgress = false
        
        let lockView = UIView(frame: lockWindow.frame)
        let keynLogoView = UIImageView(image: UIImage(named: "logo"))
        
        keynLogoView.frame = CGRect(x: 0, y: 289, width: 375, height: 88)
        keynLogoView.contentMode = .scaleAspectFit
        lockView.addSubview(keynLogoView)
        lockView.backgroundColor = UIColor(rgb: 0x46319B)
        lockView.tag = lockViewTag
        
        lockWindow.addSubview(lockView)
        lockWindow.bringSubview(toFront: lockView)
        
        // TODO: Make autolayout constrained
        //            keynLogoView.heightAnchor.constraint(equalToConstant: 88).isActive = true
        //            keynLogoView.widthAnchor.constraint(equalTo: lockView.widthAnchor).isActive = true
        //            keynLogoView.centerXAnchor.constraint(equalTo: lockView.centerXAnchor).isActive = true
        //            keynLogoView.centerYAnchor.constraint(equalTo: lockView.centerYAnchor).isActive = true
    }
    
    private func didFinishLaunchingWithOptions(notification: Notification) {
        if Seed.exists() {
            lockWindow.makeKeyAndVisible()
        }
    }
    
    // MARK: LocalAuthentication
    
    func authenticateUser(cancelChecks: Bool) {
        if cancelChecks {
            guard !authenticationInProgress && !lockWindow.isHidden && !authorizationInProgress else {
                return
            }
            if let visibleViewController = UIApplication.shared.visibleViewController {
                guard !(visibleViewController is RequestViewController) && !(visibleViewController is RegistrationRequestViewController) else {
                    return
                }
            }
            
        }
        
        authenticationInProgress = true
        authenticateUser()
    }
    
    private func authenticateUser() {
        let localAuthenticationContext = LAContext()
        localAuthenticationContext.localizedFallbackTitle = "Use Passcode"
        
        var authError: NSError?
        let reasonString = "Unlock Keyn"
        
        guard localAuthenticationContext.canEvaluatePolicy(.deviceOwnerAuthentication, error: &authError) else {
            //TODO: Show appropriate alert if biometry/TouchID/FaceID is lockout or not enrolled
            authenticationInProgress = false
            Logger.shared.error(self.evaluateAuthenticationPolicyMessageForLA(errorCode: authError!.code), error: authError)
            return
        }
        
        localAuthenticationContext.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reasonString)  { [weak self] (succes, error) in
            if succes {
                self?.unlock()
            } else if let error = error, let errorCode = authError?.code, let errorMessage = self?.evaluateAuthenticationPolicyMessageForLA(errorCode: errorCode) {
                Logger.shared.error(errorMessage, error: error as NSError)
                if error._code == LAError.userFallback.rawValue {
                    Logger.shared.debug("TODO: Handle fallback for lack of biometric authentication", error: error as NSError)
                }
            }
        }
    }
    
    func authorizePairing(url: URL, unlock: Bool = false, completion: @escaping (_: Session?, _: Error?)->()) throws {
        authorizationInProgress = true
        if let parameters = url.queryParameters, let pubKey = parameters["p"], let queueSeed = parameters["q"], let browser = parameters["b"], let os = parameters["o"] {
            do {
                guard try !Session.exists(encryptionPubKey: pubKey, queueSeed: queueSeed) else {
                    authorizationInProgress = false
                    throw SessionError.exists
                }
            } catch {
                authorizationInProgress = false
                throw SessionError.invalid
            }
            authorize(reason: "Pair with \(browser) on \(os).") { [weak self] (success, error) in
                if success {
                    do  {
                        let session = try Session.initiate(queueSeed: queueSeed, pubKey: pubKey, browser: browser, os: os)
                        self?.authorizationInProgress = false
                        completion(session, nil)
                    } catch {
                        self?.authorizationInProgress = false
                        completion(nil, error)
                    }
                    self?.unlock()
                } else if let error = error {
                    self?.authorizationInProgress = false
                    completion(nil, error)
                }
            }
        } else {
            authorizationInProgress = false
            throw SessionError.invalid
        }
    }
    
    private func unlock() {
        DispatchQueue.main.async {
            self.hideLockWindow()
            if let rootViewController = UIApplication.shared.keyWindow?.rootViewController as? RootViewController {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    if let questionnaire = Questionnaire.all().first(where: { (questionnaire) -> Bool in
                        return questionnaire.shouldAsk()
                    }) { rootViewController.presentQuestionAlert(questionnaire: questionnaire) }
                }
            }
        }
    }

    private func authorize(reason: String, completion: @escaping (_: Bool, _: Error?)->()) {
        let authenticationContext = LAContext()
        var error: NSError?
        
        guard authenticationContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            Logger.shared.error("TODO: Handle fingerprint absence.", error: error)
            return
        }
        
        authenticationContext.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: reason,
            reply: completion
        )
    }
    
    func authorizeRequest(siteName: String, accountID: String?, type: BrowserMessageType, completion: @escaping (_: Bool, _: Error?)->()) {
        var localizedReason = ""
        switch type {
        case .add, .addAndChange:
            localizedReason = "Add \(siteName)"
        case .change:
            localizedReason = "Change password for \(siteName)"
        case .login:
            localizedReason = "Login to \(siteName)"
        case .reset:
            localizedReason = "Reset password for \(siteName)"
        case .register:
            localizedReason = "Register for \(siteName)"
        default:
            localizedReason = "\(siteName)"
        }
        
        authorize(reason: localizedReason, completion: completion)
    }
    
    func launchRequestView(with notification: PushNotification) {
        authorizationInProgress = true
        do {
            if let session = try Session.getSession(id: notification.sessionID) {
                let storyboard: UIStoryboard = UIStoryboard(name: "Request", bundle: nil)
                let viewController = storyboard.instantiateViewController(withIdentifier: "PasswordRequest") as! RequestViewController
                viewController.type = notification.requestType
                viewController.notification = notification
                viewController.session = session
                if lockWindow.isHidden {
                    UIApplication.shared.visibleViewController?.present(viewController, animated: true, completion: nil)
                } else {
                    lockWindow.rootViewController?.present(viewController, animated: true, completion: nil)
                }
            } else {
                authorizationInProgress = false
                Logger.shared.warning("Received request for session that doesn't exist.")
            }
        } catch {
            authorizationInProgress = false
            Logger.shared.error("Could not decode session.", error: error as NSError)
        }
    }
    
    func evaluatePolicyFailErrorMessageForLA(errorCode: Int) -> String {
        var message = ""
        if #available(iOS 11.0, *) {
            switch errorCode {
            case LAError.biometryNotAvailable.rawValue:
                message = "Authentication could not start because the device does not support biometric authentication."
            case LAError.biometryLockout.rawValue:
                message = "Authentication could not continue because the user has been locked out of biometric authentication, due to failing authentication too many times."
            case LAError.biometryNotEnrolled.rawValue:
                message = "Authentication could not start because the user has not enrolled in biometric authentication."
            default:
                message = "Did not find error code on LAError object"
            }
        }
        
        return message
    }
    
    
    func evaluateAuthenticationPolicyMessageForLA(errorCode: Int) -> String {
        
        var message = ""
        
        switch errorCode {
        case LAError.authenticationFailed.rawValue:
            message = "The user failed to provide valid credentials"
        case LAError.appCancel.rawValue:
            message = "Authentication was cancelled by application"
        case LAError.invalidContext.rawValue:
            message = "The context is invalid"
        case LAError.notInteractive.rawValue:
            message = "Not interactive"
        case LAError.passcodeNotSet.rawValue:
            message = "Passcode is not set on the device"
        case LAError.systemCancel.rawValue:
            message = "Authentication was cancelled by the system"
        case LAError.userCancel.rawValue:
            message = "The user did cancel"
        case LAError.userFallback.rawValue:
            message = "The user chose to use the fallback"
        default:
            message = evaluatePolicyFailErrorMessageForLA(errorCode: errorCode)
        }
        
        return message
    }
    
    func hasFaceID() -> Bool {
        if #available(iOS 11.0, *) {
            let context = LAContext.init()
            var error: NSError?
            if context.canEvaluatePolicy(LAPolicy.deviceOwnerAuthenticationWithBiometrics, error: &error) {
                return context.biometryType == LABiometryType.faceID
            }
        }
        
        return false
    }
    
}
