//
//  AddSiteAuthorizer.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import LocalAuthentication
import PromiseKit

class AddBulkSiteAuthorizer: Authorizer {
    var session: BrowserSession
    let type = ChiffMessageType.addBulk
    let browserTab: Int
    let count: Int

    let requestText = "requests.add_accounts".localized.capitalizedFirstLetter
    var successText: String {
        return "\(count) \("requests.accounts_added".localized)"
    }
    var authenticationReason: String {
        return String(format: "requests.n_new_accounts".localized, count)
    }

    required init(request: ChiffRequest, session: BrowserSession) throws {
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
        }.then { (context: LAContext?) -> Promise<([(BulkAccount, PPD?)], LAContext?)> in
            self.getAccounts(startLoading: startLoading).map { ($0, context) }
        }.then { (accounts, context) -> Promise<(Int, LAContext?)> in
            startLoading?("requests.import_progress_3".localized)
            for (bulkAccount, ppd) in accounts {
                do {
                    let site = Site(name: bulkAccount.siteName, id: bulkAccount.siteId, url: bulkAccount.siteURL, ppd: ppd)
                    let account = try UserAccount(username: bulkAccount.username,
                                                  sites: [site],
                                                  password: bulkAccount.password,
                                                  rpId: nil,
                                                  algorithms: nil,
                                                  notes: bulkAccount.notes,
                                                  askToChange: nil,
                                                  context: context,
                                                  offline: true)
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
            if !succeeded.isEmpty {
                NotificationCenter.default.postMain(name: .accountsLoaded, object: nil)
            }
            if failed > 0 {
                Logger.shared.warning("Failed to import \(failed) accounts")
                throw AccountError.importError(failed: failed, total: total)
            }
            return nil
        }.ensure {
            Logger.shared.analytics(.addBulkSitesRequestAuthorized, properties: [.value: !succeeded.isEmpty])
        }
    }

    // MARK: - Private functions

    private func getAccounts(startLoading: ((String?) -> Void)?) -> Promise<[(BulkAccount, PPD?)]> {
        startLoading?("requests.import_progress_1".localized)
        return firstly {
            return self.session.getPersistentQueueMessages(shortPolling: true)
        }.then { (messages: [ChiffPersistentQueueMessage]) -> Promise<[BulkAccount]> in
            if let message = messages.first(where: { $0.type == .addBulk }), let receiptHandle = message.receiptHandle {
                return self.session.deleteFromPersistentQueue(receiptHandle: receiptHandle).map { _ in
                    message.accounts!
                }
            } else {
                throw CodingError.missingData
            }
        }.then { (accounts) in
            try PPD.getDescriptors(organisationKeyPair: TeamSession.organisationKeyPair()).map { (accounts, $0) }
        }.then { (accounts, ppdDescriptors: [PPDDescriptor]) -> Promise<[(BulkAccount, PPD?)]> in
            startLoading?("requests.import_progress_2".localized)
            return when(fulfilled: accounts.map { self.getPPD(account: $0, ppdDescriptors: ppdDescriptors )})
        }
    }

    private func getPPD(account: BulkAccount, ppdDescriptors: [PPDDescriptor]) -> Promise<(BulkAccount, PPD?)> {
        guard (ppdDescriptors.contains { $0.id == account.siteId }) else {
            return Promise.value((account, nil))
        }
        return firstly {
            try PPD.get(id: account.siteId, organisationKeyPair: TeamSession.organisationKeyPair()).map { (account, $0) }
        }
    }

}
