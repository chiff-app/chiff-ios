/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import Foundation
import LocalAuthentication

enum AuthenticationType {
    case never          // Never presents LocalAuthentication. Should be used with main context. Can be ran on main queue
    case ifNeeded       // Only presents LocalAuthentication if needed. Uses the main context.
    case always         // Always presents LocalAuthentication. Used without context, so a new one is created automatically
    case override       // Always presents LocalAuthentication and cancels any current operations. Used without context, so a new one is created
}

class LocalAuthenticationManager {
    static let shared = LocalAuthenticationManager()
    var mainContext: LAContext = LAContext()

    private var localAuthenticationQueue: OperationQueue = {
        var queue = OperationQueue()
        queue.name = "LocalAuthenticationQueue"
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .userInteractive
        return queue
    }()

    var authenticationInProgress: Bool {
        return localAuthenticationQueue.operationCount > 0
    }

    func execute(query: [String: Any], type: AuthenticationType, with context: LAContext? = nil, operation: @escaping (_ query: [String: Any], _ context: LAContext) -> Void) throws {
        var mutableQuery = query
        switch type {
        case .never:
            if context == nil {
                try checkMainContext()
            }
            mutableQuery[kSecUseAuthenticationContext as String] = context ?? mainContext
            mutableQuery[kSecUseAuthenticationUI as String] = kSecUseAuthenticationUISkip
            let task = AuthenticationOperation(with: context ?? mainContext, query: mutableQuery, operation: operation)
            localAuthenticationQueue.addOperation(task)
        case .ifNeeded:
            if context == nil {
                try checkMainContext()
            }
            mutableQuery[kSecUseAuthenticationContext as String] = context ?? mainContext
            let task = AuthenticationOperation(with: context ?? mainContext, query: mutableQuery, operation: operation)
            localAuthenticationQueue.addOperation(task)
        case .always:
            let usedContext = context ?? LAContext()
            mutableQuery[kSecUseAuthenticationContext as String] = usedContext
            let task = AuthenticationOperation(with: usedContext, query: mutableQuery, operation: operation)
            localAuthenticationQueue.addOperation(task)
        case .override:
            let usedContext = context ?? LAContext()
            mutableQuery[kSecUseAuthenticationContext as String] = usedContext
            localAuthenticationQueue.cancelAllOperations() // Only cancels cancellable operations
            let task = AuthenticationOperation(with: usedContext, query: mutableQuery, operation: operation)
            localAuthenticationQueue.addOperation(task)
        }
    }

    func evaluatePolicy(reason: String, with context: LAContext? = nil, completion: @escaping (_ context: LAContext?, _ error: Error?) -> Void) {
        let usedContext = context ?? LAContext()
        usedContext.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { (result, error) in
            if let error = error {
                return completion(nil, error)
            }
            return completion(result ? usedContext : nil, nil)
        }
    }

    func unlock(reason: String, completion: @escaping (_: Bool, _: Error?) -> ()) {
        do {
            try checkMainContext()
            mainContext.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason,
                reply: completion
            )
        } catch {
            Logger.shared.warning("Localauthentication failed")
            completion(false, error)
        }
    }

    private func checkMainContext() throws {
        var authError: NSError?
        if !mainContext.canEvaluatePolicy(.deviceOwnerAuthentication, error: &authError) {
            guard authError!.code != LAError.invalidContext.rawValue else {
                mainContext = LAContext()
                return
            }
            throw authError!
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
        // TODO: differentiate in type of operation for cancelling
        context.invalidate()
    }
}
