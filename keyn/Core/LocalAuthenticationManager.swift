/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import Foundation
import LocalAuthentication

enum AuthenticationType {
    case ifNeeded       // Only presents LocalAuthentication if needed. Uses the main context.
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

    func authenticate(reason: String, withMainContext: Bool, completion: @escaping (_ context: LAContext?, _ error: Error?) -> Void) {
        do {
            if withMainContext {
                try checkMainContext()
            }
            let context = withMainContext ? mainContext : LAContext()
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { (result, error) in
                if let error = error {
                    return completion(nil, error)
                }
                if result {
                    self.mainContext = context
                    return completion(context, nil)
                } else {
                    return completion(nil, nil)
                }
            }
        } catch {
            Logger.shared.warning("Localauthentication failed")
            completion(nil, error)
        }
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
        // TODO: differentiate in type of operation for cancelling
        context.invalidate()
    }
}
