//
//  AuthenticationManager.swift
//  TresorMockup
//
//  Created by OKU Junichirou on 2020/03/08.
//  Copyright © 2020 OKU Junichirou. All rights reserved.
//

// https://swift-ios.keicode.com/ios/touchid-faceid-auth.php
// https://medium.com/@alx.gridnev/ios-keychain-using-secure-enclave-stored-keys-8f7c81227f4
// https://medium.com/flawless-app-stories/ios-security-tutorial-part-2-c481036170ca

import Foundation
import LocalAuthentication
import SwiftyBeaver

class AuthenticationManger {
    private static var _manager: AuthenticationManger? = nil
    private static var _calledFirst = false
    
    static var shared: AuthenticationManger = {
        if _manager == nil {
            _manager     = AuthenticationManger()
            _calledFirst = true
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
        
        if type(of: self)._calledFirst {
            type(of: self)._calledFirst = false
            #if DEBUG
            // try? CryptorSeed.delete()
            // try? Validator.delete()
            #endif
        }
        
        if !Cryptor.isPrepared  {
            let vc =
                (viewController.storyboard?.instantiateViewController(identifier: "SetPasswordViewController"))!
            vc.modalPresentationStyle = .pageSheet
            vc.modalTransitionStyle   = .coverVertical
            viewController.navigationController?.present(vc, animated: true)
        }
        else {
            if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &authError) {
                context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { (success, error) in
                    if success {
                        guard let data =
                                try? SecureStore.shared.read(label: "PASS", iCloud: false) else {
                            SwiftyBeaver.self.error("SecureStore read pass Error \(error!)")
                            return
                        }
                        
                        // get a CryptorSeed string value from SecItem
                        guard var pass = String(data: data, encoding: .utf8) else {
                            SwiftyBeaver.self.error("SecureStore read pass Broken \(error!)")
                            return
                        }
                        defer{ pass = "" }
                        
                        do {
                            try Cryptor.prepare(password: pass)
                        }
                        catch (let error) {
                            SwiftyBeaver.error("Cryptor.prepare error = \(error)")
                        }
                    }
                    else {
                        print("Authenticaion Error \(error!)")
                        SwiftyBeaver.self.error("Authenticaion Error \(error!)")
                        return
                    }
                }
            }
            else {
                SwiftyBeaver.self.error("Authenticaion Error \(authError!)")
                let vc =
                    (viewController.storyboard?.instantiateViewController(identifier: "PasswordViewController"))!
                vc.modalPresentationStyle = .pageSheet
                vc.modalTransitionStyle   = .coverVertical
                viewController.navigationController?.present(vc, animated: true)
            }
        }
    }
}


// MARK: -

class SetPasswordViewController: UIViewController, UITextFieldDelegate {
    
    @IBOutlet var showPasswordSwitch: UISwitch!
    @IBOutlet var passwordTextField1: UITextField!
    @IBOutlet var passwordTextField2: UITextField!
    @IBOutlet var okButton:  UIButton!
    
    //    private var password1: String? = nil
    //    private var password2: String? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.passwordTextField1.delegate = self
        self.passwordTextField2.delegate = self
        self.showPasswordSwitch.isOn = false
        self.passwordTextField1.isSecureTextEntry = true
        self.passwordTextField2.isSecureTextEntry = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.passwordTextField1.becomeFirstResponder()
        self.okButton.isEnabled = true
    }
    
    @IBAction func switchChanged(_ sender: UISwitch) {
        let on = sender.isOn
        self.passwordTextField1.isSecureTextEntry = !on
        self.passwordTextField2.isSecureTextEntry = !on
    }
    
    @IBAction func pressed(_ sender: Any) {
        let password1 = self.passwordTextField1.text ?? ""
        let password2 = self.passwordTextField2.text ?? ""
        
        if password1 == "" || password2 == "" {
            let alert = UIAlertController(title: "Password Empty",
                                          message: "Please enter again",
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(alert, animated: true)
            
        }
        else if password1 != password2 {
            let alert = UIAlertController(title: "Not Match",
                                          message: "Please enter again",
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(alert, animated: true)
        }
        else {
            do {
                try Cryptor.prepare(password: password1)
            }
            catch (let error) {
                SwiftyBeaver.error("Cryptor.prepare error = \(error)")
                return
            }
            guard let data = password1.data(using: .utf8) else {
                SwiftyBeaver.self.error("SecureStore write pass \(password1)")
                return
            }
            do {
                try SecureStore.shared.write(label: "PASS", data, iCloud: false)
            }
            catch(let error) {
                SwiftyBeaver.self.error("SecureStore write pass Error \(error)")
                return
            }
            
            self.dismiss(animated: true)
        }
    }
    
    //    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
    //        if self.passwordTextField1.isFirstResponder {
    //            password1 = self.passwordTextField1.text
    //            #if DEBUG
    //            SwiftyBeaver.self.debug("password1 = \(password1 ?? "nil")")
    //            #endif
    //        }
    //        else if self.passwordTextField2.isFirstResponder {
    //            password2 = self.passwordTextField2.text
    //            #if DEBUG
    //            SwiftyBeaver.self.debug("password2 = \(password2 ?? "nil")")
    //            #endif
    //        }
    //        return true
    //    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if self.passwordTextField1.isFirstResponder {
            self.passwordTextField2.becomeFirstResponder()
        }
        else if self.passwordTextField2.isFirstResponder {
            self.passwordTextField1.becomeFirstResponder()
        }
        return true
    }
    
    //    func textFieldDidEndEditing(_ textField: UITextField) {
    //        if self.passwordTextField1.isFirstResponder {
    //            password1 = self.passwordTextField1.text
    //            #if DEBUG
    //            SwiftyBeaver.self.debug("password1 = \(password1 ?? "nil")")
    //            #endif
    //        }
    //        else if self.passwordTextField2.isFirstResponder {
    //            password2 = self.passwordTextField2.text
    //            #if DEBUG
    //            SwiftyBeaver.self.debug("password2 = \(password2 ?? "nil")")
    //            #endif
    //        }
    //    }
}

// MARK: -
class PasswordViewController: UIViewController, UITextFieldDelegate {
    
    @IBOutlet var showPasswordSwitch: UISwitch!
    @IBOutlet var passwordTextField: UITextField!
    @IBOutlet var okButton:  UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.passwordTextField.delegate = self
        self.showPasswordSwitch.isOn = false
        self.passwordTextField.isSecureTextEntry = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.passwordTextField.becomeFirstResponder()
        self.okButton.isEnabled = true
    }
    
    @IBAction func switchChanged(_ sender: UISwitch) {
        let on = sender.isOn
        self.passwordTextField.isSecureTextEntry = !on
    }
    
    @IBAction func pressed(_ sender: Any) {
        let password1 = self.passwordTextField.text ?? ""
        
        if password1 == "" {
            let alert = UIAlertController(title: "Password Empty",
                                          message: "Please enter again",
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(alert, animated: true)
        }
        else {
            do {
                try Cryptor.prepare(password: password1)
            }
            catch (let error) {
                SwiftyBeaver.error("Cryptor.prepare error = \(error)")
                let alert = UIAlertController(title: "Wrong Password",
                                              message: "Please enter again",
                                              preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(alert, animated: true)
                return
            }
            self.dismiss(animated: true)
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        return true
    }
}
