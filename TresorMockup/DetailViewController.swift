//
//  DetailViewController.swift
//  TresorMockup
//
//  Created by OKU Junichirou on 2018/02/25.
//  Copyright (C) 2018 OKU Junichirou. All rights reserved.
//

import UIKit

// MARK: -
class LabelCell: UITableViewCell {
    @IBOutlet weak var label: CopyableLabel?
}

class TextFieldCell: UITableViewCell {
    @IBOutlet weak var textField: UITextField?
}

class TextViewCell: UITableViewCell {
    @IBOutlet weak var textView: UITextView?
}

class DisclosureCell: UITableViewCell {
    @IBOutlet weak var label: CopyableLabel?
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
}

// MARK: -
// http://stephenradford.me/make-uilabel-copyable/
// https://gist.github.com/zyrx/67fa2f42b567d1d4c8fef434c7987387

class CopyableLabel: UILabel {

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

    @objc func showMenu(sender: AnyObject?) {
        self.becomeFirstResponder()
        let menu = UIMenuController.shared
        if !menu.isMenuVisible {
            menu.setTargetRect(bounds, in: self)
            menu.setMenuVisible(true, animated: true)
        }
    }

    override func copy(_ sender: Any?) {
        UIPasteboard.general.string = self.text
        UIMenuController.shared.setMenuVisible(false, animated: true)
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        return action == #selector(UIResponderStandardEditActions.copy)
    }

    override var canBecomeFirstResponder: Bool {
        get {return true }
    }
}


// MARK: -
class DetailViewController: UITableViewController, UITextFieldDelegate {
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
        .password: "CellLabel",
        .selectAt: "CellLabel",
        .memo:     "CellLabel",
        ]
    var keyCell_edit: [AppKeyType: String] = [
        .title:    "CellTextField",
        .url:      "CellTextField",
        .userid:   "CellTextField",
        .password: "CellTextField",
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
            if !(self.splitViewController?.isCollapsed ?? true) &&
                (self.detailItem?.hasChanges ?? false) {
                if let context = self.detailItem?.managedObjectContext {
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
    }

    weak var passTextField: UITextField? = nil


    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.

        self.tableView.estimatedRowHeight      = 44.0
        self.tableView.rowHeight               = UITableViewAutomaticDimension
        self.navigationItem.rightBarButtonItem = editButtonItem
        configureView()

        guard self.detailItem != nil else {
            return
        }
        // DEBUG CODE
        //        self.detailItem?.title    = "Apple"
        //        self.detailItem?.url      = "http://www.apple.com"
        //        self.detailItem?.memo     = "Hello world!"
        //        self.detailItem?.selectAt = Date()
        //        self.detailItem?.loginAt  = Date()
        // DEBUG CODE

        self.detailItem?.forMaxLength = max((self.detailItem?.forMaxLength)!, 4)
        if self.detailItem?.forCharSet.rawValue == 0 {
            self.detailItem?.forCharSet = self.charsArray.first!
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.clearsSelectionOnViewWillAppear = self.splitViewController!.isCollapsed
    }


    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        if (self.detailItem?.hasChanges ?? false) {
            if let context = self.detailItem?.managedObjectContext {
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

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    override func setEditing(_ editing: Bool, animated: Bool) {
        guard self.detailItem != nil else {
            return
        }
        self.tableView.performBatchUpdates(
            { () -> Void in
                let beforePaths = AppKeyType.iterator.flatMap {
                    self.layouter.indexPath(forKey: $0)
                }
                let beforeSections = beforePaths.map { $0.section }

                super.setEditing(editing, animated: animated)

                let afterPaths = AppKeyType.iterator.flatMap {
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
                let t = (cell as! TextFieldCell).textField
                t?.text = self.detailItem?.title
                t?.tag  = TAG_TEXTFIELD_TITLE
                t?.delegate = self
            }
            else {
                (cell as! LabelCell).label?.text = self.detailItem?.title
            }
        case .url:
            if self.isEditing {
                let t = (cell as! TextFieldCell).textField
                t?.text = self.detailItem?.url
                t?.tag  = TAG_TEXTFIELD_URL
                t?.delegate = self
            }
            else {
                (cell as! LabelCell).label?.text = self.detailItem?.url
            }

        case .userid:
            if self.isEditing {
                let t = (cell as! TextFieldCell).textField
                t?.text = self.detailItem?.userid
                t?.tag  = TAG_TEXTFIELD_USERID
                t?.delegate = self
            }
            else {
                (cell as! LabelCell).label?.text = self.detailItem?.userid
            }

        case .password:
            if self.isEditing {
                let t = (cell as! TextFieldCell).textField
                t?.text = self.detailItem?.password
                t?.tag  = TAG_TEXTFIELD_PASSWORD
                t?.delegate = self
                self.passTextField = t
            }
            else {
                (cell as! LabelCell).label?.text = self.detailItem?.password
                self.passTextField = nil
            }

        case .selectAt:
            (cell as! LabelCell).label?.text = (detailItem?.selectAt?.description(with: nil) ?? "")

        case .memo:
            if self.isEditing {
                (cell as! TextViewCell).textView?.text = detailItem?.value(forKey: self.keyAttribute[key]!) as? String
            }
            else {
                (cell as! LabelCell).label?.text = detailItem?.value(forKey: self.keyAttribute[key]!) as? String
            }

        case .generator:
            let len = self.detailItem!.forMaxLength
            let c   = cell as! GeneratorCell
            c.lengthSlider?.minimumValue = 4
            c.lengthSlider?.maximumValue = 32.0
            c.lengthSlider?.value        = Float( len )
            c.lengthSlider?.isContinuous = true
            c.lengthSlider?.tag          = TAG_STEPPER_LENGTH
            c.lengthSlider?.addTarget(self,
                                      action: #selector(valueChanged(sender:forEvent:)),
                                      for: .valueChanged)
            c.lengthLabel?.text = String( format: "%d", len )

            let chars = self.detailItem!.forCharSet
            c.charsStepper?.minimumValue  = 0.0
            c.charsStepper?.maximumValue  = Double(charsArray.count - 1)
            c.charsStepper?.value         = Double(
                (charsArray.index {$0.rawValue >= chars.rawValue} ?? 0) )
            c.charsStepper?.isContinuous  = true
            c.charsStepper?.tag           = TAG_STEPPER_CHARS
            c.charsStepper?.addTarget(self,
                                      action: #selector(self.valueChanged(sender:forEvent:)),
                                      for: .valueChanged)
            c.charsLabel?.text            = chars.description

            c.generateButton?.tag         = TAG_BUTTON_GENERATE
            c.generateButton?.addTarget(self,
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

    @objc func valueChanged(sender: UIControl, forEvent event: UIEvent) {
        let getcell = {
            (_ view: UIView?) -> UITableViewCell? in
            var c = view?.superview
            while c != nil && !(c is UITableViewCell) {
                c = c?.superview
            }
            return c as? UITableViewCell
        }
        guard let cell = getcell(sender) else {
            assertionFailure()
            return
        }

        switch sender.tag {
        case TAG_BUTTON_GENERATE:
            let len   = self.detailItem!.forMaxLength
            let chars = self.detailItem!.forCharSet
            if let val = try? RandomData.shared.get(count: len, in: chars) {
                self.passTextField?.text = val
                self.detailItem?.password = val
            }

        case TAG_STEPPER_LENGTH:
            let val = Int((sender as! UISlider).value)
            (cell as? GeneratorCell)?.lengthLabel?.text = String( format: "%d", val )
            self.detailItem?.forMaxLength = val

        case TAG_STEPPER_CHARS:
            let val = Int((sender as! UIStepper).value)
            let chr = self.charsArray[ Int(val) ]
            (cell as? GeneratorCell)?.charsLabel?.text = chr.description
            self.detailItem?.forCharSet = chr

        default:
            assertionFailure()
        }
    }

    @objc func textFieldChanged(_ textField: UITextField) {
        switch textField.tag {
        case TAG_TEXTFIELD_PASSWORD:
            if let str = self.passTextField?.text {
                self.detailItem?.setValue(str as AnyObject,
                                          forKey: "password")
            }
        default:
            assertionFailure()
        }
    }
//}

// MARK: - extension
//extension DetailViewController: UITextFieldDelegate {
    func textFieldDidEndEditing(_ textField: UITextField) {
        switch textField.tag {
        case TAG_TEXTFIELD_TITLE:
            if let str = textField.text {
                self.detailItem?.title = str
            }

        case TAG_TEXTFIELD_URL:
            if let str = textField.text {
                self.detailItem?.url = str
            }

        case TAG_TEXTFIELD_USERID:
            if let str = textField.text {
                self.detailItem?.userid = str
            }

        case TAG_TEXTFIELD_PASSWORD:
            if let str = textField.text {
                self.detailItem?.password = str
            }

        default:
            assertionFailure()
        }
    }
}
