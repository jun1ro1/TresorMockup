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
    
    init() {}
    
    // https://stackoverflow.com/questions/24158062/how-to-use-touch-id-sensor-in-ios-8/40612228
    func authenticate(_ viewController: UIViewController) {
        let context = LAContext()
        let reason  = "This app uses Touch ID / Facd ID to secure your data."
        var authError: NSError? = nil
        var authed = false
        
        if !Cryptor.isPrepared  {
            
        }
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &authError) {
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { (success, error) in
                if success {
                    authed = true
                }
                else {
                    print("Authenticaion Error \(error!)")
                    SwiftyBeaver.self.error("Authenticaion Error \(error!)")
                    authed = false
                }
            }
        }
        else {
            SwiftyBeaver.self.error("Authenticaion Error \(authError!)")
            DialogManager.shared.showSetPassword(viewController) {
                (password) in
                #if DEBUG
                SwiftyBeaver.self.debug("password = \(password ?? "nil")")
                #endif
            }
        }
        //        if authed {
        //            self.authenticated = true
        //        }
    }
}

fileprivate class DialogManager {
    private static var _manager: DialogManager? = nil
    static var shared: DialogManager = {
        if _manager == nil {
            _manager = DialogManager()
        }
        return _manager!
    }()
    
    let MAKE_PASSWORD_PASS    = 11
    let MAKE_PASSWORD_CONFIRM = 12
    
    private var handler: ((String?) -> Void)?
    
    init() {}
    
    private enum setPasswordState {
        case initial
        case password1
        case password2
    }
    private     var _setPassword: UIAlertController? = nil
    fileprivate func setPassword( _ handler: @escaping (String?)->Void ) -> UIAlertController? {
        
        if self._setPassword == nil {
            let alert = UIAlertController(title: "Set App password",
                                          message: "Enter Password",
                                          preferredStyle: .alert)
            alert.addTextField()
            alert.addTextField()
            let passTextField    = alert.textFields![0]
            let confirmTextField = alert.textFields![1]
            
            //            passTextField.isEnabled    = true
            passTextField.tag          = MAKE_PASSWORD_PASS
            //            passTextField.delegate     = self
            
            //            confirmTextField.isEnabled = true
            confirmTextField.tag       = MAKE_PASSWORD_CONFIRM
            //            confirmTextField.delegate  = self
            
            alert.addAction(
                UIAlertAction(title: "OK", style: .default) { Void in
                    let password = self._setPassword?.textFields?.first?.text
                    #if DEBUG
                    SwiftyBeaver.self.debug("password = \(password ?? "nil")")
                    #endif
                    self.handler?(password)
                }
            )
            alert.addAction(
                UIAlertAction(title: "Cancel", style: .cancel) { Void in
                    #if DEBUG
                    SwiftyBeaver.self.debug("password = nil")
                    #endif
                    self.handler?(nil)
                }
            )
            self._setPassword = alert
        }
        return self._setPassword
    }
    
    func showSetPassword(_ viewController: UIViewController,
                         _ handler: @escaping (String?)->Void) {
        
        let alert1 = UIAlertController(title: "Set App password",
                                      message: "Enter Password",
                                      preferredStyle: .alert)
        let alert2 = UIAlertController(title: "Set App password",
                                      message: "Re-enter Password",
                                      preferredStyle: .alert)
        alert1.addTextField()
        alert2.addTextField()

        var password1: String? = nil
        var password2: String? = nil
        
        let handler1: (String?)->Void = { pass in
            viewController.present(alert2, animated: true)
        }
        
        alert1.addAction(
            UIAlertAction(title: "OK", style: .default) { Void in
                password1 = alert1.textFields?.first?.text
                #if DEBUG
                SwiftyBeaver.self.debug("password1 = \(password1 ?? "nil")")
                #endif
                handler1(password1)
            }
        )
        alert1.addAction(
            UIAlertAction(title: "Cancel", style: .cancel) { Void in
                password1 = nil
                #if DEBUG
                SwiftyBeaver.self.debug("password = nil")
                #endif
            }
        )
        
        alert2.addAction(
            UIAlertAction(title: "OK", style: .default) { Void in
                password2 = alert2.textFields?.first?.text
                #if DEBUG
                SwiftyBeaver.self.debug("password2 = \(password2 ?? "nil")")
                #endif
                if password1 == password2 {
                    handler(password2)
                }
                else {
                    alert2.message = "not match password, re-enter"
                    viewController.present(alert2, animated: true)
                }
            }
        )
        alert2.addAction(
            UIAlertAction(title: "Cancel", style: .cancel) { Void in
                password2 = nil
                #if DEBUG
                SwiftyBeaver.self.debug("password = nil")
                #endif
                handler(nil)
            }
        )

       viewController.present(alert1, animated: true)
    }
}

//
//func showEnterPasswordDialogue(_ viewController: UIViewController,
//                               _ handler: (String?) -> Void) {
//    let alert = UIAlertController(title: "Unlock App", message: "Enter Password", preferredStyle: .alert)
//    alert.addTextField()
//    let okAction = UIAlertAction(title: "OK", style: .default) {
//        Void in
//        let password = alert.textFields?.first?.text
//        #if DEBUG
//        SwiftyBeaver.self.debug("password = \(password ?? "nil")")
//        #endif
//        handler(password)
//    }
//    let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) {
//        handler(nil)
//    }
//    alert.addAction(okAction)
//    alert.addAction(cancelAction)
//    viewController.present(alert, animated: true)
//}

