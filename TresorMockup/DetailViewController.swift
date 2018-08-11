//
//  DetailViewController.swift
//  TresorMockup
//
//  Created by OKU Junichirou on 2018/02/25.
//  Copyright (C) 2018 OKU Junichirou. All rights reserved.
//

import UIKit


// MARK: -
class DetailViewController: UITableViewController {
    //    let lengthArray: [Int16]             = [ 4, 5, 6, 8, 10, 12, 14, 16, 20, 24, 32 ]
    let charsArray: [CypherCharacterSet] = [
        CypherCharacterSet.DecimalDigits,
        CypherCharacterSet.UppercaseLatinAlphabets,
        CypherCharacterSet.LowercaseLatinAlphabets,
        CypherCharacterSet.UpperCaseLettersSet,
        CypherCharacterSet.LowerCaseLettersSet,
        CypherCharacterSet.AlphaNumericsSet,
        CypherCharacterSet.Base64Set,
        CypherCharacterSet.ArithmeticCharactersSet,
        CypherCharacterSet.AlphaNumericSymbolsSet,
        ].sorted { $0.rawValue < $1.rawValue }
    let TAG_BUTTON_GENERATE    =  10
    let TAG_STEPPER_LENGTH     =  20
    let TAG_STEPPER_CHARS      =  30
    let TAG_TEXTFIELD_TITLE    = 110
    let TAG_TEXTFIELD_URL      = 120
    let TAG_TEXTFIELD_USERID   = 130
    let TAG_TEXTFIELD_LENGTH   = 140
    let TAG_TEXTFIELD_PASSWORD = 150
    let TAG_LABEL_PASSWORD     = 160
    let TAG_BUTTON_EYE         = 170


    fileprivate var layouter_nonedit = Layouter<AppKeyType>([
        .title:        (section: 0, row: 0),
        .url:          (section: 0, row: 1),
        .userid:       (section: 1, row: 0),
        .password:     (section: 1, row: 1),
        .selectAt:     (section: 1, row: 2),
        .memo:         (section: 2, row: 0),
        ])

    fileprivate var layouter_edit = Layouter<AppKeyType>([
        .title:        (section: 0, row: 0),
        .url:          (section: 0, row: 1),
        .userid:       (section: 1, row: 0),
        .password:     (section: 1, row: 1),
        .generator:    (section: 1, row: 2),
        .memo:         (section: 2, row: 0),
        ])

    fileprivate var layouter: Layouter<AppKeyType> {
        return self.isEditing ? self.layouter_edit : self.layouter_nonedit
    }

    var keyCell_nonedit: [AppKeyType: String] = [
        .title:    "CellLabel",
        .url:      "CellLabel",
        .userid:   "CellLabel",
        .password: "CellPassword",
        .selectAt: "CellLabel",
        .memo:     "CellDisclosure",
        ]
    var keyCell_edit: [AppKeyType: String] = [
        .title:    "CellTextField",
        .url:      "CellTextField",
        .userid:   "CellTextField",
        .password: "CellSecretTextField",
        .selectAt: "CellLabel",
        .generator:"CellGenerator",
        .memo:     "CellDisclosure",
        ]
    var keyCell: [AppKeyType: String] {
        return self.isEditing ? self.keyCell_edit : self.keyCell_nonedit
    }

    var keyAttribute: [AppKeyType: String] = [
        .title:    "title",
        .url:      "url",
        .userid:   "userid",
        .password: "password",
        .selectAt: "selectAt",
        .memo:     "memo",
        ]


    // MARK: - Properties
    var detailItem: Site? {
        didSet {
            self.tableView.reloadData()
        }
    }

    weak var passTextField: UITextField? = nil

    private weak var passwordManager: PasswordManager? = PasswordManager.shared

    // MARK: - Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.

        // set default detailItem value
        if self.detailItem?.forMaxLength == 0 {
            self.detailItem?.forMaxLength = 8
        }
        if self.detailItem?.forCharSet.rawValue == 0 {
            self.detailItem?.forCharSet = CypherCharacterSet.AlphaNumericsSet
        }

        self.tableView.estimatedRowHeight      = 44.0
        self.tableView.rowHeight               = UITableViewAutomaticDimension
        self.navigationItem.rightBarButtonItem = editButtonItem
        configureView()

    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.clearsSelectionOnViewWillAppear = self.splitViewController!.isCollapsed

        guard self.detailItem != nil else {
            return
        }

        self.detailItem?.addObserver(self, forKeyPath: "selectAt", options: [], context: nil)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        self.view.viewWithTag(TAG_TEXTFIELD_TITLE)?.becomeFirstResponder()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        if self.isEditing {
            self.setEditing(false, animated: false)
        }
        self.detailItem?.removeObserver(self, forKeyPath: "selectAt")

        guard self.detailItem != nil else { return }
        guard self.detailItem!.title != nil ||
            self.detailItem!.url   != nil ||
            self.detailItem!.memo  != nil  else {
                // dispose the empty item
                if let context = self.detailItem!.managedObjectContext {
                    context.delete(self.detailItem!)
                    self.detailItem = nil
                    context.performAndWait {
                        do {
                            try context.save()
                        }
                        catch {
                            print("error = \(error)")
                            abort()
                        }
                    }
                }
                return
        }
    }


    override func viewDidDisappear(_ animated: Bool) {
        self.save(force: true)
        super.viewDidDisappear(animated)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        guard self.detailItem != nil else {
            return
        }

        if !editing {
            var recur: ((UIView) -> Void)?
            recur = { (view: UIView) -> Void in
                (view as? UITextField)?.resignFirstResponder()
                view.subviews.forEach { recur!($0) }
            }
            recur!(self.view)
        }

        if let keys = self.detailItem?.changedValues().keys, keys.contains("passwordCurrent") {
            print("changed passwordCurrent = \(String(describing: self.detailItem?.passwordCurrent))")
            if let str = self.detailItem?.passwordCurrent as String?,
                let password = self.passwordManager?.newObject(for: self.detailItem!) {
                password.password = str
                self.passwordManager?.select(password: password, for: self.detailItem!)
                self.save()
            }
        }

        self.tableView.performBatchUpdates(
            { () -> Void in
                let beforePaths = AppKeyType.iterator.compactMap {
                    self.layouter.indexPath(forKey: $0)
                }
                let beforeSections = beforePaths.map { $0.section }

                super.setEditing(editing, animated: animated)

                let afterPaths = AppKeyType.iterator.compactMap {
                    self.layouter.indexPath(forKey: $0)
                }
                let afterSections = afterPaths.map { $0.section }

                self.tableView.insertSections(
                    IndexSet(afterSections).subtracting(IndexSet(beforeSections)),
                    with: .fade)
                self.tableView.deleteSections(
                    IndexSet(beforeSections).subtracting(IndexSet(afterSections)),
                    with: .fade)

                self.tableView.insertRows(
                    at: Array( Set(afterPaths).subtracting(Set(beforePaths)) ),
                    with: .fade)
                self.tableView.deleteRows(
                    at: Array( Set(beforePaths).subtracting(Set(afterPaths)) ),
                    with: .fade)
                self.tableView.reloadRows(
                    at: Array( Set(afterPaths).intersection(Set(beforePaths)) ),
                    with: .fade)
        },
            completion: nil )

    }

    // MARK: - Segue
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segue.identifier {
        case "SegueText":
            guard let viewController = segue.destination as? TextViewController else {
                assertionFailure()
                return
            }
            viewController.text = self.detailItem?.memo ?? ""
            viewController.setEditing(self.isEditing, animated: false)

        case "SeguePassoword":
            let controller = segue.destination as! PasswordTableViewController
            controller.detailItem = self.detailItem

        default:
            assertionFailure()
        }
    }

    @IBAction func unwindToMaster(unwindSegue: UIStoryboardSegue) {
        switch unwindSegue.identifier {
        case "TextViewToMaster":
            if let vc = unwindSegue.source as? TextViewController {
                self.detailItem?.memo = vc.text ?? ""
                self.save()
            }
            else {
                assertionFailure()
            }
        case "PasswordTableToMaster":
            break
        default:
            assertionFailure()
        }
    }

    // MARK: - private mothds
    fileprivate func save(force: Bool = false) {
        guard self.detailItem != nil        else { return }
        guard self.detailItem!.hasChanges   else { return }

        var cond = false
        if let svc = self.splitViewController {
            cond = (!svc.isCollapsed || force)
        }
        else {
            cond = force
        }

        guard cond else { return }

        if let context = self.detailItem!.managedObjectContext {
            context.performAndWait {
                do {
                    try context.save()
                }
                catch {
                    print("error = \(error)")
                    abort()
                }
            }
        }
    }

    // MARK: - Table View
    override func numberOfSections(in tableView: UITableView) -> Int {
        guard self.detailItem != nil else {
            return 0
        }
        return self.layouter.numberOfSections
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if self.isEditing {
            return [
                "Site".localized,
                "User ID".localized,
                "Password".localized,
                "Memo".localized,
                ][ section ]

        }
        else {
            return [
                "Site".localized,
                "Account".localized,
                "Memo".localized,
                ][ section ]
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard self.detailItem != nil else {
            return 0
        }

        return self.layouter.numberOfRows(inSection: section)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let key = self.layouter.key(forIndexPath: indexPath) ?? .typeEnd
        let cell = tableView.dequeueReusableCell(withIdentifier: self.keyCell[key]!, for: indexPath)
        guard self.detailItem != nil else {
            return cell
        }

        switch key {
        case .title:
            if self.isEditing {
                let tf = (cell as! TextFieldCell).textField
                tf?.text = self.detailItem?.title
                tf?.tag  = TAG_TEXTFIELD_TITLE
                tf?.placeholder = "Title".localized
                tf?.accessibilityIdentifier = "textFieldTitle"
                tf?.delegate = self
            }
            else {
                (cell as! LabelCell).label?.text = self.detailItem?.title
            }
        case .url:
            if self.isEditing {
                let tf = (cell as! TextFieldCell).textField
                tf?.text = self.detailItem?.url
                tf?.tag  = TAG_TEXTFIELD_URL
                tf?.placeholder = "URL".localized
                tf?.accessibilityIdentifier = "textFieldURL"
                tf?.delegate = self
            }
            else {
                (cell as! LabelCell).label?.text = self.detailItem?.url
            }

        case .userid:
            if self.isEditing {
                let tf = (cell as! TextFieldCell).textField
                tf?.text = self.detailItem?.userid
                tf?.tag  = TAG_TEXTFIELD_USERID
                tf?.placeholder = "User ID".localized
                tf?.accessibilityIdentifier = "textFieldUser"
                tf?.delegate = self
            }
            else {
                (cell as! LabelCell).label?.text = self.detailItem?.userid
            }

        case .password:
            if self.isEditing {
                let tf = (cell as! SecretTextViewCell).textField
                tf?.text = (self.detailItem?.passwordCurrent as String?) ?? ""
                tf?.tag  = TAG_TEXTFIELD_PASSWORD
                tf?.placeholder = "Password".localized
                tf?.accessibilityIdentifier = "textFieldPassword"
                tf?.delegate = self
                tf?.clearsOnInsertion = false

                // https://stackoverflow.com/questions/7305538/uitextfield-with-secure-entry-always-getting-cleared-before-editing
                tf?.clearsOnBeginEditing = false
                self.passTextField = tf

                let button   = (cell as! SecretTextViewCell).eyeButton
                button?.tag  = TAG_BUTTON_EYE
                button?.addTarget(self,
                                  action: #selector(showPassword(sender:)),
                                  for: .touchDown)
                button?.addTarget(self,
                                  action: #selector(hidePoassword(sender:)),
                                  for: [.touchUpInside, .touchUpOutside])
            }
            else {
                let label    = (cell as! PasswordCell).label
                label?.value = (self.detailItem?.passwordCurrent as String?) ?? ""
                label?.tag   = TAG_LABEL_PASSWORD
                label?.secret(true)
                let button   = (cell as! PasswordCell).eyeButton
                button?.tag  = TAG_BUTTON_EYE
                button?.addTarget(self,
                                  action: #selector(showPassword(sender:)),
                                  for: .touchDown)
                button?.addTarget(self,
                                  action: #selector(hidePoassword(sender:)),
                                  for: [.touchUpInside, .touchUpOutside])
                self.passTextField = nil
            }

        case .selectAt:
            (cell as! LabelCell).label?.text = detailItem?.forSelectAt

        case .memo:
            (cell as! DisclosureCell).label?.text = detailItem?.value(forKey: self.keyAttribute[key]!) as? String

        case .generator:
            let len = self.detailItem!.forMaxLength
            let cl   = cell as! GeneratorCell
            cl.lengthSlider?.minimumValue = 4
            cl.lengthSlider?.maximumValue = 32.0
            cl.lengthSlider?.value        = Float( len )
            cl.lengthSlider?.isContinuous = true
            cl.lengthSlider?.tag          = TAG_STEPPER_LENGTH
            cl.lengthSlider?.addTarget(self,
                                       action: #selector(valueChanged(sender:forEvent:)),
                                       for: .valueChanged)
            cl.lengthLabel?.text = String( format: "%d", len )

            let chars = self.detailItem!.forCharSet
            cl.charsStepper?.minimumValue  = 0.0
            cl.charsStepper?.maximumValue  = Double(charsArray.count - 1)
            cl.charsStepper?.value         = Double(
                (charsArray.index {$0.rawValue >= chars.rawValue} ?? 0) )
            cl.charsStepper?.isContinuous  = true
            cl.charsStepper?.tag           = TAG_STEPPER_CHARS
            cl.charsStepper?.addTarget(self,
                                       action: #selector(self.valueChanged(sender:forEvent:)),
                                       for: .valueChanged)
            cl.charsLabel?.text            = chars.description

            cl.generateButton?.tag         = TAG_BUTTON_GENERATE
            cl.generateButton?.addTarget(self,
                                         action: #selector(self.valueChanged(sender:forEvent:)),
                                         for: .touchDown)

        default:
            assertionFailure()

        }

        return cell
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return false
    }

    func configureView() {

        // Update the user interface for the detail item.
        //        if let detail = detailItem {
        //            if let label = detailDescriptionLabel {
        //                //            label.text = detail.timestamp!.description
        //            }
        //        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let key = self.layouter.key(forIndexPath: indexPath) ?? .typeEnd
        switch key {
        case .url:
            guard let cell = tableView.cellForRow(at: indexPath) as? LabelCell else {
                return
            }
            if let str = cell.label?.text {
                if let url = NSURL(string: str) as URL? {
                    if UIApplication.shared.canOpenURL(url) {
                        UIApplication.shared.open(url, options:[:])
                    }
                }
            }

        default:
            tableView.deselectRow(at: indexPath, animated: true)
        }

    }

    fileprivate func getcell(_ view: UIView?) -> UITableViewCell? {
        var c = view?.superview
        while c != nil && !(c is UITableViewCell) {
            c = c?.superview
        }
        return c as? UITableViewCell
    }

    @objc func valueChanged(sender: UIControl, forEvent event: UIEvent) {
        guard let cell = getcell(sender) else {
            assertionFailure()
            return
        }

        switch sender.tag {
        case TAG_BUTTON_GENERATE:
            let len   = self.detailItem!.forMaxLength
            let chars = self.detailItem!.forCharSet
            if let val = try? RandomData.shared.get(count: len, in: chars) {
                self.detailItem?.passwordCurrent = val as NSString
                self.passTextField?.text = val
//                if let password = self.passwordManager?.newObject(for: self.detailItem!) {
//                    password.password = val
//                    self.passwordManager?.select(password: password, for: self.detailItem!)
//                    self.passTextField?.text = val
//                    self.save()
//                }
            }

        case TAG_STEPPER_LENGTH:
            let val = Int((sender as! UISlider).value)
            (cell as? GeneratorCell)?.lengthLabel?.text = String( format: "%d", val )
            self.detailItem?.forMaxLength = val
            //            self.save()


        case TAG_STEPPER_CHARS:
            let val = Int((sender as! UIStepper).value)
            let chr = self.charsArray[ Int(val) ]
            (cell as? GeneratorCell)?.charsLabel?.text = chr.description
            self.detailItem?.forCharSet = chr
            //            self.save()

        default:
            assertionFailure()
        }
    }

    // MARK: -
    @objc func showPassword(sender: UIControl) {
        guard let cell = getcell(sender) else {
            assertionFailure()
            return
        }

        switch cell {
        case is PasswordCell:
            (cell as! PasswordCell).label?.secret(false)
        case is SecretTextViewCell:
            // https://stackoverflow.com/questions/34922331/getting-and-setting-cursor-position-of-uitextfield-and-uitextview-in-swift
            let tf = (cell as! SecretTextViewCell).textField
            tf?.isSecureTextEntry = false
            //             if let tp = tf?.endOfDocument {
            //                tf?.selectedTextRange = tf?.textRange(from: tp, to: tp)
        //            }
        default:
            assertionFailure()
        }
    }

    @objc func hidePoassword(sender: UIControl) {
        guard let cell = getcell(sender) else {
            assertionFailure()
            return
        }

        switch cell {
        case is PasswordCell:
            (cell as! PasswordCell).label?.secret(true)
        case is SecretTextViewCell:
            (cell as! SecretTextViewCell).textField?.isSecureTextEntry = true
        default:
            assertionFailure()
        }
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        switch keyPath {
        case "selectAt":
            let indexPaths: [IndexPath] = [.password, .selectAt].compactMap {
                self.layouter.indexPath(forKey: $0)
            }
            if !self.tableView.isEditing {
                self.tableView.reloadRows(at: indexPaths, with: .automatic)
            }
        default:
            assertionFailure()

        }
    }
}

// MARK: - extension
extension DetailViewController: UITextFieldDelegate {
    func textFieldDidEndEditing(_ textField: UITextField) {
        switch textField.tag {
        case TAG_TEXTFIELD_TITLE:
            if let str = textField.text {
                if str == "" && self.detailItem?.title == nil {
                    // preserve nil
                }
                else {
                    self.detailItem?.title = str
                    self.save()
                }
            }

        case TAG_TEXTFIELD_URL:
            if let str = textField.text {
                if str == "" && self.detailItem?.url == nil {
                    // preserve nil
                }
                else {
                    self.detailItem?.url = str
                    self.save()
                }
            }

        case TAG_TEXTFIELD_USERID:
            if let str = textField.text {
                if str == "" && self.detailItem?.userid == nil {
                    // preserve nil
                }
                else {
                    self.detailItem?.userid = str
                    self.save()
                }
            }

        case TAG_TEXTFIELD_PASSWORD:
            if let str = textField.text {
                if str == "" && (self.detailItem?.passwordCurrent as String?) == nil {
                    // preserve nil
                }
                else {
                    self.detailItem?.passwordCurrent = str as NSString
//                    if let password = self.passwordManager?.newObject(for: self.detailItem!) {
//                        password.password = str
//                        self.passwordManager?.select(password: password, for: self.detailItem!)
//                        self.save()
//                    }
                }
            }

        default:
            assertionFailure()
        }
    }

    /*
     // https://stackoverflow.com/questions/7305538/uitextfield-with-secure-entry-always-getting-cleared-before-editing
     func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
     // https://stackoverflow.com/questions/25138339/nsrange-to-rangestring-index
     // https://stackoverflow.com/questions/7305538/uitextfield-with-secure-entry-always-getting-cleared-before-editing
     if let tx = textField.text {
     textField.text = tx.replacingCharacters(in: Range(range, in: tx)!, with: string)
     }

     let tp = textField.endOfDocument
     textField.selectedTextRange = textField.textRange(from: tp, to: tp)

     //        let selectedRange = NSMakeRange(range.location + string.count, 0)
     //        let from = textField.position(from: textField.beginningOfDocument, offset:selectedRange.location)
     //        let to = textField.position(from: from!, offset:selectedRange.length)
     //        textField.selectedTextRange = textField.textRange(from: from!, to: to!)

     return false
     }
     */
}

// MARK: -
class LabelCell: UITableViewCell {
    @IBOutlet weak var label: CopyableValueLabel?
}

class TextFieldCell: UITableViewCell {
    @IBOutlet weak var textField: UITextField?
}

class TextViewCell: UITableViewCell {
    @IBOutlet weak var textView: UITextView?
}

class DisclosureCell: UITableViewCell {
    @IBOutlet weak var label: CopyableValueLabel?
}

class PasswordCell: UITableViewCell {
    @IBOutlet weak var label: CopyableValueLabel?
    @IBOutlet weak var eyeButton: UIButton?

}

class SecretTextViewCell: UITableViewCell {
    @IBOutlet weak var textField: UITextField?
    @IBOutlet weak var eyeButton: UIButton?
}

class GeneratorCell: UITableViewCell {
    @IBOutlet weak var lengthLabel:    UILabel?
    @IBOutlet weak var lengthSlider:   UISlider?
    @IBOutlet weak var charsLabel:     UILabel?
    @IBOutlet weak var charsStepper:   UIStepper?
    @IBOutlet weak var generateButton: UIButton?
}

// MARK: -
fileprivate extension Site {
    var forCharSet: CypherCharacterSet {
        get {
            return CypherCharacterSet(rawValue: (self.value(forKey: "charSet") as? UInt32) ?? 0)
        }
        set {
            self.setValue(Int32(newValue.rawValue) as AnyObject, forKey: "charSet")
        }
    }

    var forMaxLength: Int {
        get { return (self.value(forKey: "maxLength") as? Int) ?? 0 }
        set { self.setValue(Int16(newValue) as AnyObject, forKey: "maxLength") }
    }

    var forCreatedAt: String {
        get {
            guard let date = self.value(forKey: "createdAt") as? Date else { return "" }
            return DateFormatter.localizedString(from: date, dateStyle: .medium,timeStyle: .medium)
        }
    }

    var forSelectAt: String {
        get {
            guard let date = self.value(forKey: "selectAt") as? Date else { return "" }
            return DateFormatter.localizedString(from: date, dateStyle: .medium,timeStyle: .medium)
        }
    }
}

// MARK: -

// https://stackoverflow.com/questions/7305538/uitextfield-with-secure-entry-always-getting-cleared-before-editing
class PasswordTextField: UITextField {
    override var isSecureTextEntry: Bool {
        didSet {
            if self.isFirstResponder {
                _ = self.becomeFirstResponder()
            }
        }
    }

    override func becomeFirstResponder() -> Bool {
        let success = super.becomeFirstResponder()
        if self.isSecureTextEntry, let text = self.text {
            self.text?.removeAll()
            self.insertText(text)
            self.text = text
        }
        return success
    }
}


// http://stephenradford.me/make-uilabel-copyable/
// https://gist.github.com/zyrx/67fa2f42b567d1d4c8fef434c7987387

class CopyableValueLabel: UILabel {

    private var val: String?
    var value: String? {
        get { return self.val }
        set { self.val = newValue }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.isUserInteractionEnabled = true
        self.addGestureRecognizer(UILongPressGestureRecognizer(target: self,
                                                               action: #selector(self.showMenu)))
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.isUserInteractionEnabled = true
        self.addGestureRecognizer(UILongPressGestureRecognizer(target: self,
                                                               action: #selector(self.showMenu)))
    }

    func secret(_ secret: Bool) {
        let pass     = self.value ?? ""
        if secret {
            self.text = String(repeating: "•", count: pass.count)
        } else {
            self.text = pass
        }
    }

    @objc func showMenu(sender: AnyObject?) {
        self.becomeFirstResponder()
        let menu = UIMenuController.shared
        if !menu.isMenuVisible {
            menu.setTargetRect(bounds, in: self)
            menu.setMenuVisible(true, animated: true)
        }
    }

    override func copy(_ sender: Any?) {
        UIPasteboard.general.string = self.value ?? self.text
        UIMenuController.shared.setMenuVisible(false, animated: true)
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        return action == #selector(UIResponderStandardEditActions.copy)
    }

    override var canBecomeFirstResponder: Bool {
        get { return true }
    }
}


