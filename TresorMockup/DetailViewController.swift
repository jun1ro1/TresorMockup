//
//  DetailViewController.swift
//  TresorMockup
//
//  Created by OKU Junichirou on 2018/02/25.
//  Copyright (C) 2018 OKU Junichirou. All rights reserved.
//

import UIKit

enum AppKeyType: Int  {
    case  title = 0
    case  url
    case  userid
    case  password
    case  selectAt
    case  memo
    case  typeEnd

    var description: String {
        var s: String = "**UNKNOWN**AppKeyType"
        switch self {
        case .title:      s = "Title"
        case .url:        s = "URL"
        case .userid:     s = "User ID"
        case .password:   s = "Password"
        case .selectAt:   s = "Select at"
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

fileprivate enum SectionType: Int {
    case site = 0
    case account
    case memo
    case typeEnd

    var description: String {
        var s: String = "**UNKNOWN**SectionType"
        switch self {
        case .site:    s = "Site   "
        case .account: s = "Account"
        case .memo:    s = "Memo  "
        case .typeEnd: s = "TypeEnd"
        }
        return s
    }

    var header: String {
        return [
            "Site".localized,
            "Account".localized,
            "Memo",
            ][self.rawValue]
    }
    static var count: Int { return SectionType.typeEnd.rawValue }

    static var iterator: AnyIterator<SectionType> {
        var value: Int = -1
        return AnyIterator {
            value = value + 1
            guard value < SectionType.typeEnd.rawValue else {
                return nil
            }
            return SectionType(rawValue: value)!
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

// MARK: -
class DetailViewController: UITableViewController {

    fileprivate var layouter_nonedit = J1Layouter<SectionType, AppKeyType>([
        .title:        (section: .site,    row: 0),
        .url:          (section: .site,    row: 1),
        .userid:       (section: .account, row: 0),
        .password:     (section: .account, row: 1),
        .selectAt:     (section: .account, row: 2),
        .memo:         (section: .memo,    row: 0),
        ])

    fileprivate var layouter_edit = J1Layouter<SectionType, AppKeyType>([
        .title:        (section: .site,    row: 0),
        .url:          (section: .site,    row: 1),
        .userid:       (section: .account, row: 0),
        .password:     (section: .account, row: 1),
        .selectAt:     (section: .account, row: 2),
        .memo:         (section: .memo,    row: 0),
        ])

    fileprivate var layouter: J1Layouter<SectionType, AppKeyType> {
        return self.inEditing ? self.layouter_edit : self.layouter_nonedit
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
        .memo:     "CellTextView",
    ]
    var keyCell: [AppKeyType: String] {
        return self.inEditing ? self.keyCell_edit : self.keyCell_nonedit
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

    private var inEditing = false

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.

        self.inEditing = false
        self.tableView.estimatedRowHeight = 44.0
        self.tableView.rowHeight          = UITableViewAutomaticDimension
        self.configureButtons(animated: false)
        configureView()

        // DEBUG CODE
        self.detailItem?.title    = "Apple"
        self.detailItem?.url      = "http://www.apple.com"
        self.detailItem?.userid   = "username"
        self.detailItem?.password = "password"
        self.detailItem?.memo     = "Hello world!"
        self.detailItem?.selectAt = Date()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    override func setEditing(_ editing: Bool, animated: Bool) {
        self.inEditing = editing

        var paths: [IndexPath] = []
        for key in AppKeyType.iterator {
            if let indexPath = self.layouter.indexPath(forKey: key) {
                paths.append(indexPath)
            }
        }

        self.tableView.beginUpdates()
        self.tableView.reloadRows(at: paths, with: .fade)
        self.tableView.endUpdates()

        self.configureButtons(animated: animated)
    }

    @objc func setToEditingMode(sender: AnyObject) {
        self.setEditing(true, animated: true)
    }

    @objc func exitFromEditintgMode(sender: AnyObject) {
        self.setEditing(false, animated: true)
    }


    func configureButtons(animated: Bool) {
        if  self.inEditing {
            let addButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector( DetailViewController.exitFromEditintgMode))
            self.navigationItem.setRightBarButton(addButton, animated: animated)
        }
        else {
            let addButton = UIBarButtonItem(barButtonSystemItem: .edit, target: self, action: #selector( setToEditingMode ) )
            self.navigationItem.setRightBarButton(addButton, animated: animated)
        }
    }

    // MARK: - Table View
    override func numberOfSections(in tableView: UITableView) -> Int {
        return SectionType.count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let sec = SectionType(rawValue: section) else {
            return nil
        }
        return sec.header
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let sec = SectionType(rawValue: section) else {
            return 0
        }
        return self.layouter.numberOfRows(inSection: sec)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let key = self.layouter.key(forIndexPath: indexPath) ?? .typeEnd
        let cell = tableView.dequeueReusableCell(withIdentifier: self.keyCell[key]!, for: indexPath)

        switch key {
        case .title, .url, .userid, .password:
            if self.inEditing {
                (cell as! TextFieldCell).textField?.text = detailItem?.value(forKey: self.keyAttribute[key]!) as? String
            }
            else {
                (cell as! LabelCell).label?.text = detailItem?.value(forKey: self.keyAttribute[key]!) as? String
            }

        case .selectAt:
            (cell as! LabelCell).label?.text = "since " + (detailItem?.selectAt?.description ?? "")

        case .memo:
            if self.inEditing {
                (cell as! TextViewCell).textView?.text = detailItem?.value(forKey: self.keyAttribute[key]!) as? String
            }
            else {
                (cell as! LabelCell).label?.text = detailItem?.value(forKey: self.keyAttribute[key]!) as? String
            }

        default:
            assertionFailure()

        }

        return cell
    }
    
    func configureView() {

        // Update the user interface for the detail item.
//        if let detail = detailItem {
//            if let label = detailDescriptionLabel {
//                //            label.text = detail.timestamp!.description
//            }
//        }
    }

}

