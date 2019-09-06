//
//  FakeLAContext.swift
//  keynTests
//
//  Created by brandon maldonado alonso on 9/5/19.
//  Copyright © 2019 keyn. All rights reserved.
//

import LocalAuthentication

class FakeLAContext: LAContext {
    override func evaluatePolicy(_ policy: LAPolicy, localizedReason: String, reply: @escaping (Bool, Error?) -> Void) {
        reply(true, nil)
    }
    override func canEvaluatePolicy(_ policy: LAPolicy, error: NSErrorPointer) -> Bool {
        return true
    }
}
