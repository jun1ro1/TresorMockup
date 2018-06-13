//
//  TextViewController.swift
//  Anpi2
//
//  Created by OKU Junichirou on 2018/03/25
//  Copyright (c) 2018 OKU Junichirou. All rights reserved.
//

import UIKit

class TextViewController: UIViewController {

    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var bottomConstraint: NSLayoutConstraint!

    var text: String? = nil
    var deferred = false

    override func viewDidLoad() {
        super.viewDidLoad()

        // add Done button to the navigation bar
        self.navigationItem.rightBarButtonItem =
            UIBarButtonItem(barButtonSystemItem: .done,
                            target: self, action:#selector(action))

        // https://stackoverflow.com/questions/37825327/swift-3-nsnotificationcenter-keyboardwillshow-hide
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.keyboardWillShow(notification:)),
            name: Notification.Name.UIKeyboardWillShow,
            object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.keyboardWillHide(notification:)),
            name: Notification.Name.UIKeyboardWillHide,
            object: nil)

        // set a text to the text view after it is loaded
        self.textView.text = self.text ?? ""
        self.textView.delegate = self
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.textView.becomeFirstResponder()
    }

    override func viewWillDisappear(_ animated: Bool) {
        // update AppData deferredly
        if self.deferred {
            self.text = self.textView.text ?? ""
            self.deferred = false
        }
        super.viewWillDisappear(animated)
    }
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @objc func action()->Void {
        self.textView.resignFirstResponder()
        // updating AppData is deferred on a compact view
        self.deferred = true
        if let sv = self.splitViewController {
            if !sv.isCollapsed {
                // update AppData immediately on a regular view
                self.text = self.textView.text ?? ""
                self.deferred = false
            }
        }
        self.performSegue(withIdentifier: "TextViewToMaster", sender: self)
    }

    /*
     // MARK: - Navigation

     // In a storyboard-based application, you will often want to do a little preparation before navigation
     override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
     // Get the new view controller using segue.destinationViewController.
     // Pass the selected object to the new view controller.
     }
     */

    @objc func keyboardWillShow(notification: Notification) {
        guard let info = notification.userInfo else {
            assertionFailure()
            return
        }

        guard let height = (info[UIKeyboardFrameEndUserInfoKey] as? NSValue)?
            .cgRectValue.size.height else {
                assertionFailure()
                return
        }

        guard let duration = (info[UIKeyboardAnimationDurationUserInfoKey] as? TimeInterval) else {
            assertionFailure()
            return
        }

        self.bottomConstraint.constant = 0.0 - height
        UIView.animate(withDuration: duration,
                       animations: { () -> Void in self.view.layoutIfNeeded() }
        )
    }

    @objc func keyboardWillHide(notification: Notification) {
        guard let info = notification.userInfo else {
            assertionFailure()
            return
        }

        guard let duration = (info[UIKeyboardAnimationDurationUserInfoKey] as? TimeInterval) else {
            assertionFailure()
            return
        }

        self.bottomConstraint.constant = 0.0
        UIView.animate(withDuration: duration,
                       animations: { () -> Void in self.view.layoutIfNeeded() }
        )
    }
}

extension TextViewController: UITextViewDelegate {

    func textViewDidChange(_ textView: UITextView) {
//        self.deferred = true // needed to write back the text view text to AppData
//        if let sv = self.splitViewController {
//            if !sv.isCollapsed {
//                // update AppData immediately on a regular view
                self.text = self.textView.text ?? ""
//                self.deferred = false
//            }
//        }
    }
}
