//
//  SSHCreateAuthorizer.swift
//  ChiffCore
//
//  Copyright: see LICENSE.md
//

import LocalAuthentication
import PromiseKit

public class SSHCreateAuthorizer: Authorizer {
    public var session: BrowserSession
    public let type = ChiffMessageType.sshCreate
    public let browserTab: Int
    public let code: String? = nil
    let name: String
    let algorithm: SSHAlgorithm
    public var logParam: String {
        return name
    }

    public let requestText = "requests.create_ssh_key".localized.capitalizedFirstLetter
    public let successText = "requests.ssh_key_created".localized.capitalizedFirstLetter
    public var authenticationReason: String {
        return "requests.generate_ssh".localized
    }
    public var verify = false
    public var verifyText: String? = nil

    public required init(request: ChiffRequest, session: BrowserSession) throws {
        self.session = session
        guard let browserTab = request.browserTab,
              let name = request.siteName,
              let algorithms = request.algorithms else {
            throw AuthorizationError.missingData
        }
        self.browserTab = browserTab
        self.name = name
        switch algorithms.first {
        case .ECDSA256:
            self.algorithm = .ECDSA256
        case .edDSA:
            self.algorithm = .edDSA
        default:
            throw SSHError.notSupported
        }
        Logger.shared.analytics(.createSSHKeyRequestOpened)
    }

    public func authorize(verification: String?, startLoading: ((String?) -> Void)?) -> Promise<Account?> {
        var success = false
        return firstly {
            self.authenticate(verification: verification)
        }.then { (context: LAContext) -> Promise<(SSHIdentity, LAContext)> in
            let identity = try SSHIdentity(algorithm: self.algorithm, name: self.name, context: context)
            return identity.backup().map { (identity, context) }
        }.map { (identity, context) in
            try self.session.sendSSHResponse(identity: identity, browserTab: self.browserTab, type: .sshCreate, context: context, signature: nil)
            NotificationCenter.default.postMain(name: .accountsLoaded, object: nil)
            success = true
            return nil
        }.ensure {
            self.writeLog(isRejected: false)
            Logger.shared.analytics(.createSSHKeyRequestAuthorized, properties: [.value: success])
        }
    }

}
