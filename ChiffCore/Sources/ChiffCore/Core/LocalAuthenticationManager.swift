//
//  LocalAuthenticationManager.swift
//  ChiffCore
//
//  Copyright: see LICENSE.md
//

import Foundation
import LocalAuthentication
import PromiseKit

public enum AuthenticationType {
    /// Only presents LocalAuthentication if needed. Uses the main context.
    case ifNeeded
    /// Always presents LocalAuthentication and cancels any current operations. Used without context, so a new one is created
    case override
}

/// Manages and queues the LocalAuthentication requests to prevent duplicate requests.
public class LocalAuthenticationManager {

    public static let shared = LocalAuthenticationManager()

    /// The main context. This generally should be authenticated when app is open and invalidated when the app is closed.
    public var mainContext: LAContext = LAContext()

    private var localAuthenticationQueue: OperationQueue = {
        var queue = OperationQueue()
        queue.name = "LocalAuthenticationQueue"
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .userInteractive
        return queue
    }()

    /// Checks if there is any authentication in progress.
    public var authenticationInProgress: Bool {
        return localAuthenticationQueue.operationCount > 0
    }

    /// Checks if the main context is authenticated.
    public var isAuthenticated: Bool {
        return mainContext.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    func execute(query: [String: Any], type: AuthenticationType, with context: LAContext? = nil, operation: @escaping (_ query: [String: Any], _ context: LAContext) -> Void) throws {
        var mutableQuery = query
        switch type {
        case .ifNeeded:
            if context == nil {
                try checkMainContext()
            }
            mutableQuery[kSecUseAuthenticationContext as String] = context ?? mainContext
            let task = AuthenticationOperation(with: context ?? mainContext, query: mutableQuery, operation: operation)
            localAuthenticationQueue.addOperation(task)
        case .override:
            let usedContext = context ?? LAContext()
            mutableQuery[kSecUseAuthenticationContext as String] = usedContext
            localAuthenticationQueue.cancelAllOperations() // Only cancels cancellable operations
            let task = AuthenticationOperation(with: usedContext, query: mutableQuery, operation: operation)
            localAuthenticationQueue.addOperation(task)
        }
    }

    /// Authenticate the user, creating an authenticated `LAContext` object.
    /// - Parameters:
    ///   - reason: The reason that should be presented to the user.
    ///   - withMainContext: If this is false, a new context is created, effectively making sure the authentication popup is presented.
    /// - Returns: The authenticated `LAContext` object.
    public func authenticate(reason: String, withMainContext: Bool) -> Promise<LAContext> {
        return Promise { seal in
            do {
                if withMainContext {
                    try checkMainContext()
                }
                let context = withMainContext ? mainContext : LAContext()
                context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { (evaluationResult, error) in
                    if evaluationResult {
                        self.mainContext = context
                        return seal.fulfill(context)
                    } else {
                        return seal.reject(error!)
                    }
                }
            } catch {
                Logger.shared.warning("Localauthentication failed")
                seal.reject(error)
            }
        }
    }

    /// A helper function to determine if an `LAError` is actionable or not.
    ///
    /// Some errors indicate there may something wrong in the app, while others are thrown when, for example, the user cancels the operation.
    /// - Parameter error: The error that should be checked.
    /// - Returns: A localized user-friendly error string.
    public func handleError(error: Error) -> String? {
        switch error {
        case KeychainError.authenticationCancelled, LAError.appCancel, LAError.systemCancel, LAError.userCancel:
            // Not interesting, do nothing.
            break
        case LAError.invalidContext, LAError.notInteractive:
            Logger.shared.error(error.localizedDescription, error: error)
            return "errors.local_authentication.generic".localized
        case LAError.passcodeNotSet:
            Logger.shared.error(error.localizedDescription, error: error)
            return "errors.local_authentication.passcode_not_set".localized
        case let error as LAError:
            if #available(iOS 11.0, *) {
                switch error {
                case LAError.biometryNotAvailable:
                    return "errors.local_authentication.biometry_not_available".localized
                case LAError.biometryNotEnrolled:
                    return "errors.local_authentication.biometry_not_enrolled".localized
                default:
                    Logger.shared.warning("An LA error occured that was not catched \(error.localizedDescription). Check if it should be..", error: error)
                }
            } else {
                Logger.shared.warning("An LA error occured that was not catched. Check if it should be.. \(error.localizedDescription)", error: error)
            }
        default:
            Logger.shared.warning("An LA error occured that was not catched. Check if it should be.. \(error.localizedDescription)", error: error)
        }
        return nil
    }

    // MARK: - Private functions

    private func checkMainContext() throws {
        var authError: NSError?
        if !mainContext.canEvaluatePolicy(.deviceOwnerAuthentication, error: &authError) {
            if authError!.code == LAError.invalidContext.rawValue || authError!.code == NSXPCConnectionInvalid {
                mainContext = LAContext()
                return
            } else {
                throw authError!
            }
        }
    }

}

class AuthenticationOperation: Operation {
    private var context: LAContext
    private let operation: (_ query: [String: Any], _ context: LAContext) -> Void
    private let query: [String: Any]

    init(with context: LAContext, query: [String: Any], operation: @escaping (_ query: [String: Any], _ context: LAContext) -> Void) {
        self.context = context
        self.operation = operation
        self.query = query
    }

    override func main() {
        guard !isCancelled else {
            return
        }
        operation(query, context)
    }

    override func cancel() {
        super.cancel()
        context.invalidate()
    }
}
