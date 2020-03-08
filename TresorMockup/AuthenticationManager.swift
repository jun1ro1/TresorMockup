//
//  AuthenticationManager.swift
//  TresorMockup
//
//  Created by OKU Junichirou on 2020/03/08.
//  Copyright © 2020 OKU Junichirou. All rights reserved.
//

// https://swift-ios.keicode.com/ios/touchid-faceid-auth.php
import Foundation
import LocalAuthentication
import SwiftyBeaver

class AuthenticationManger {
    private static var _manager: AuthenticationManger? = nil
    static var shared: AuthenticationManger = {
        if _manager == nil {
            _manager = AuthenticationManger()
        }
        return _manager!
    }()
    
    private var mutex = NSLock()
    private var _authenticated = false
    private var authenticated: Bool {
        get {
            self.mutex.lock()
            let val = self._authenticated
            self.mutex.unlock()
            return val
        }
        set {
            self.mutex.lock()
            self._authenticated = newValue
            self.mutex.unlock()
        }
    }
    
    init() {
        
    }
    
    func authenticate() -> Bool {
        let context = LAContext()
        let reason  = "This app uses Touch ID / Facd ID to secure your data."
        var authError: NSError? = nil
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &authError) {
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { (success, error) in
                if success {
                    self.authenticated = true
                }
                else {
                    print("Authenticaion Error \(error!)")
                    SwiftyBeaver.self.error("Authenticaion Error \(error!)")
                }
            }
        }
        else {
            print("Authenticaion Error \(authError!)")
            SwiftyBeaver.self.error("Authenticaion Error \(authError!)")
            
        }
        return true
    }
}
