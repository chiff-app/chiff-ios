//
//  SSHLoginAuthorizer.swift
//  ChiffCore
//
//  Copyright: see LICENSE.md
//

import LocalAuthentication
import PromiseKit

public class SSHLoginAuthorizer: Authorizer {
    public var session: BrowserSession
    public let type = ChiffMessageType.sshLogin
    public let browserTab: Int
    public let challenge: String
    public let id: String
    public var logParam: String

    public let requestText = "requests.ssh_login".localized.capitalizedFirstLetter
    public let successText = "requests.ssh_login_success".localized.capitalizedFirstLetter
    public var authenticationReason: String {
        return "requests.ssh_login_authentication".localized
    }

    public required init(request: ChiffRequest, session: BrowserSession) throws {
        self.session = session
        guard let browserTab = request.browserTab,
              let name = request.siteName,
              let id = request.accountID,
              let challenge = request.challenge else {
            throw AuthorizationError.missingData
        }
        self.browserTab = browserTab
        self.challenge = challenge
        self.id = id
        self.logParam = name
        Logger.shared.analytics(.loginWithSSHRequestOpened)
    }

    public func authorize(startLoading: ((String?) -> Void)?) -> Promise<Account?> {
        var success = false
        return firstly {
            LocalAuthenticationManager.shared.authenticate(reason: self.authenticationReason, withMainContext: false)
        }.then { (context: LAContext) -> Promise<Account?> in
            guard var identity = try SSHIdentity.get(id: self.id, context: context) else {
                throw AccountError.notFound
            }
            let signature = try identity.sign(challenge: self.challenge)
            try self.session.sendSSHResponse(identity: identity, browserTab: self.browserTab, type: .sshLogin, context: context, signature: signature)
            try identity.save()
            NotificationCenter.default.postMain(name: .accountsLoaded, object: nil)
            success = true
            return .value(nil)
        }.ensure {
            self.writeLog(isRejected: false)
            Logger.shared.analytics(.loginWithSSHRequestAuthorized, properties: [.value: success])
        }
    }

}
