//
//  DetailViewController.swift
//  TresorMockup
//
//  Created by OKU Junichirou on 2018/02/25.
//  Copyright (C) 2018 OKU Junichirou. All rights reserved.
//

import UIKit

enum AppKeyType: Int  {
    case title = 0
    case url
    case userid
    case password
    case selectAt
    case generator
    case memo
    case typeEnd

    var description: String {
        var s: String = "**UNKNOWN**AppKeyType"
        switch self {
        case .title:      s = "Title"
        case .url:        s = "URL"
        case .userid:     s = "User ID"
        case .password:   s = "Password"
        case .selectAt:   s = "Select at"
        case .generator:  s = "Generator"
        case .memo:       s = "Memo"
        case .typeEnd:    s = "TypeEnd"
        }
        return s
    }

    // MARK: class functions
    /// - parameter:
    /// - retunrs: the number of AppKeyType elements
    static var count: Int { return AppKeyType.typeEnd.rawValue }
    static var iterator: AnyIterator<AppKeyType> {
        var value: Int = -1
        return AnyIterator {
            value = value + 1
            guard value < AppKeyType.typeEnd.rawValue else {
                return nil
            }
            return AppKeyType(rawValue: value)!
        }
    }
}



// MARK: -
class LabelCell: UITableViewCell {
    @IBOutlet weak var label: UILabel?
}

class TextFieldCell: UITableViewCell {
    @IBOutlet weak var textField: UITextField?
}

class TextViewCell: UITableViewCell {
    @IBOutlet weak var textView: UITextView?
}

class GeneratorCell: UITableViewCell {
    @IBOutlet weak var lengthLabel:    UILabel?
    @IBOutlet weak var lengthStepper:  UIStepper?
    @IBOutlet weak var charsLabel:     UILabel?
    @IBOutlet weak var charsStepper:   UIStepper?
    @IBOutlet weak var generateButton: UIButton?

//    required init?(coder aDecoder: NSCoder) {
//        super.init(coder: aDecoder)
//        self.okButton?.tag     = 10
//        self.lengthSlider?.tag = 20
//        self.charsStepper?.tag = 30
//
////      fatalError("init(coder:) has not been implemented")
//    }
//

//    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
//        super.init(style: style, reuseIdentifier: reuseIdentifier)
//
//        self.okButton?.tag     = 10
//        self.lengthSlider?.tag = 20
//        self.charsStepper?.tag = 30
//    }
//
}

// MARK: -
class DetailViewController: UITableViewController {
    let lengthArray: [Int16]             = [ 4, 5, 6, 8, 10, 12, 14, 16, 20, 24, 32 ]
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
    ]
    let TAG_BUTTON_GENERATE = 10
    let TAG_STEPPER_LENGTH  = 20
    let TAG_STEPPER_CHARS   = 30

    var randomLength: Int16 = 0
    var randomChars:  CypherCharacterSet = .DecimalDigits

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
        .memo:     "CellTextView",
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


    // MARK: Properties
    var detailItem: Site?
    //    {
    //        didSet {
    //            // Update the view.
    //            configureView()
    //        }
    //    }

    weak var randTextField: UITextField?


    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.

//        self.isEditing = false
        self.tableView.estimatedRowHeight      = 44.0
        self.tableView.rowHeight               = UITableViewAutomaticDimension
        self.navigationItem.rightBarButtonItem = editButtonItem
        configureView()

        // DEBUG CODE
        self.detailItem?.title    = "Apple"
        self.detailItem?.url      = "http://www.apple.com"
        self.detailItem?.userid   = "username"
        self.detailItem?.password = "password"
        self.detailItem?.memo     = "Hello world!"
        self.detailItem?.selectAt = Date()

        self.randomLength = self.detailItem?.maxLength ?? self.lengthArray.first ?? 0
        self.randomChars  = self.detailItem?.charSet != nil ?
            CypherCharacterSet(rawValue: UInt32(self.detailItem!.charSet) ) : self.charsArray.first!
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    override func setEditing(_ editing: Bool, animated: Bool) {
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
        return self.layouter.numberOfRows(inSection: section)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let key = self.layouter.key(forIndexPath: indexPath) ?? .typeEnd
        let cell = tableView.dequeueReusableCell(withIdentifier: self.keyCell[key]!, for: indexPath)

        switch key {
        case .title, .url, .userid, .password:
            if self.isEditing {
                (cell as! TextFieldCell).textField?.text = detailItem?.value(forKey: self.keyAttribute[key]!) as? String
                if key == .password {
                    self.randTextField = (cell as! TextFieldCell).textField
                }
            }
            else {
                (cell as! LabelCell).label?.text = detailItem?.value(forKey: self.keyAttribute[key]!) as? String
            }

        case .selectAt:
            (cell as! LabelCell).label?.text = (detailItem?.selectAt?.description ?? "")

        case .memo:
            if self.isEditing {
                (cell as! TextViewCell).textView?.text = detailItem?.value(forKey: self.keyAttribute[key]!) as? String
            }
            else {
                (cell as! LabelCell).label?.text = detailItem?.value(forKey: self.keyAttribute[key]!) as? String
            }

        case .generator:
            (cell as! GeneratorCell).lengthStepper?.minimumValue = 0
            (cell as! GeneratorCell).lengthStepper?.maximumValue = Double(lengthArray.count - 1)
            (cell as! GeneratorCell).lengthStepper?.value        = 0.0
            (cell as! GeneratorCell).lengthStepper?.isContinuous = false
            (cell as! GeneratorCell).lengthStepper?.tag          = TAG_STEPPER_LENGTH

            (cell as! GeneratorCell).charsStepper?.minimumValue = 0.0
            (cell as! GeneratorCell).charsStepper?.maximumValue = Double(charsArray.count - 1)
            (cell as! GeneratorCell).charsStepper?.value        = 0.0
            (cell as! GeneratorCell).charsStepper?.isContinuous = false
            (cell as! GeneratorCell).charsStepper?.tag          = TAG_STEPPER_CHARS

            (cell as! GeneratorCell).generateButton?.tag        = TAG_BUTTON_GENERATE
            
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

    @IBAction func valueChanged(sender: UIControl, event forEvent: UIEvent) {
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
            if let rnd = try? RandomData.shared.get(count: Int(self.randomLength), in: self.randomChars) {
                self.randTextField?.text = rnd
            }

        case TAG_STEPPER_LENGTH:
            let val = (sender as! UIStepper).value
            let len = self.lengthArray[ Int(val) ]
            let str = String( format: "%d", len )
            (cell as? GeneratorCell)?.lengthLabel?.text = str
            self.randomLength = len

        case TAG_STEPPER_CHARS:
            let val = (sender as! UIStepper).value
            let chr = self.charsArray[ Int(val) ]
            (cell as? GeneratorCell)?.charsLabel?.text = chr.description
            self.randomChars = chr

        default:
            assertionFailure()
        }

    }
}

