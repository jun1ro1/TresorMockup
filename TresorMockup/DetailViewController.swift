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
            "",
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

fileprivate var layouter = J1Layouter<SectionType, AppKeyType>([
    .title:        (section: .site,    row: 0),
    .url:          (section: .site,    row: 1),
    .userid:       (section: .account, row: 0),
    .password:     (section: .account, row: 1),
    .selectAt:     (section: .account, row: 2),
    .memo:         (section: .memo,    row: 0),
    ])

class LabelCell: UITableViewCell {
    @IBOutlet weak var label: UILabel?
}

class TextViewCell: UITableViewCell {
    @IBOutlet weak var textView: UITextView?
}

class DetailViewController: UITableViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.

        self.tableView.estimatedRowHeight = 44.0
        self.tableView.rowHeight          = UITableViewAutomaticDimension
        configureView()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    var detailItem: Site? {
        didSet {
            // Update the view.
            configureView()
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
        return layouter.numberOfRows(inSection: sec)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell: UITableViewCell
        let key = layouter.key(forIndexPath: indexPath) ?? .typeEnd

        switch key {
        case .title:
            cell = tableView.dequeueReusableCell(withIdentifier: "CellLabel", for: indexPath) as! LabelCell
            (cell as! LabelCell).label?.text = detailItem?.title

        case .url:
            cell = tableView.dequeueReusableCell(withIdentifier: "CellLabel", for: indexPath) as! LabelCell
            (cell as! LabelCell).label?.text = detailItem?.url

        case .userid:
            cell = tableView.dequeueReusableCell(withIdentifier: "CellLabel", for: indexPath) as! LabelCell
            (cell as! LabelCell).label?.text = detailItem?.userid

        case .password:
            cell = tableView.dequeueReusableCell(withIdentifier: "CellLabel", for: indexPath) as! LabelCell
            (cell as! LabelCell).label?.text = detailItem?.password

        case .selectAt:
            cell = tableView.dequeueReusableCell(withIdentifier: "CellLabel", for: indexPath) as! LabelCell
            (cell as! LabelCell).label?.text = "since" + (detailItem?.selectAt?.description ?? "")

        case .memo:
            cell = tableView.dequeueReusableCell(withIdentifier: "CellTextView", for: indexPath) as! TextViewCell
            (cell as! TextViewCell).textView?.text = detailItem?.memo

        default:
            cell = tableView.dequeueReusableCell(withIdentifier: "CellLabel", for: indexPath)
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

