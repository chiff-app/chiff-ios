//
//  AddSiteAuthorizer.swift
//  keyn
//
//  Created by Bas Doorn on 22/10/2020.
//  Copyright © 2020 keyn. All rights reserved.
//

import LocalAuthentication
import PromiseKit

class AddBulkSiteAuthorizer: Authorizer {
    var session: BrowserSession
    let type = KeynMessageType.addBulk
    let browserTab: Int
    let count: Int

    let requestText = "requests.add_accounts".localized.capitalizedFirstLetter
    var successText: String {
        return "\(count) \("requests.accounts_added".localized)"
    }
    var authenticationReason: String {
        return String(format: "requests.n_new_accounts".localized, count)
    }

    required init(request: KeynRequest, session: BrowserSession) throws {
        self.session = session
        guard let count = request.count,
              let browserTab = request.browserTab else {
            throw AuthorizationError.missingData
        }
        self.count = count
        self.browserTab = browserTab
        Logger.shared.analytics(.addBulkSitesRequestOpened)
    }

    func authorize(startLoading: ((String?) -> Void)?) -> Promise<Account?> {
        var succeeded: [String: (UserAccount, String?)] = [:]
        var failed = 0
        return firstly {
            LocalAuthenticationManager.shared.authenticate(reason: self.authenticationReason, withMainContext: false)
        }.then { (context: LAContext?) -> Promise<([KeynPersistentQueueMessage], LAContext?)> in
            startLoading?("requests.import_progress_1".localized)
            return self.session.getPersistentQueueMessages(shortPolling: true).map { ($0, context) }
        }.then { (messages: [KeynPersistentQueueMessage], context: LAContext?) -> Promise<([BulkAccount], LAContext?)> in
            if let message = messages.first(where: { $0.type == .addBulk }), let receiptHandle = message.receiptHandle {
                return self.session.deleteFromPersistentQueue(receiptHandle: receiptHandle).map { _ in
                    (message.accounts!, context)
                }
            } else {
                throw CodingError.missingData
            }
        }.then { (accounts, context) in
            try PPD.getDescriptors(organisationKeyPair: TeamSession.organisationKeyPair()).map { (accounts, $0, context) }
        }.then { (accounts, ppdDescriptors: [PPDDescriptor], context) -> Promise<([(BulkAccount, PPD?)], LAContext?)> in
            startLoading?("requests.import_progress_2".localized)
            return when(fulfilled: try accounts.map { account in
                return ppdDescriptors.contains { $0.id == account.siteId } ?  try PPD.get(id: account.siteId, organisationKeyPair: TeamSession.organisationKeyPair()).map { (account, $0) } : Promise.value((account, nil))
            }).map { ($0, context) }
        }.then { (accounts, context) -> Promise<(Int, LAContext?)> in
            startLoading?("requests.import_progress_3".localized)
            for (bulkAccount, ppd) in accounts {
                do {
                    let site = Site(name: bulkAccount.siteName, id: bulkAccount.siteId, url: bulkAccount.siteURL, ppd: ppd)
                    let account = try UserAccount(username: bulkAccount.username, sites: [site], password: bulkAccount.password, rpId: nil, algorithms: nil, notes: bulkAccount.notes, askToChange: nil, context: context, offline: true)
                    succeeded[account.id] = (account, bulkAccount.notes)
                } catch {
                    failed += 1
                }
            }
            var promises: [Promise<Void>] = try BrowserSession.all().map { $0.updateSessionAccounts(accounts: succeeded.mapValues { $0.0 }) }
            promises.append(UserAccount.backup(accounts: succeeded))
            startLoading?("requests.import_progress_4".localized)
            return when(fulfilled: promises).asVoid().map { (accounts.count, context) }
        }.map { (total, context) in
            try self.session.sendBulkAddResponse(browserTab: self.browserTab, context: context)
            startLoading?("requests.import_progress_5".localized)
            if succeeded.count > 0 {
                NotificationCenter.default.postMain(name: .accountsLoaded, object: nil)
            }
            if failed > 0 {
                Logger.shared.warning("Failed to import \(failed) accounts")
                throw AccountError.importError(failed: failed, total: total)
            }
            return nil
        }.ensure {
            Logger.shared.analytics(.addBulkSitesRequestAuthorized, properties: [.value: succeeded.count > 0])
        }
    }

}
