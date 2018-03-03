//
//  DetailViewController.swift
//  TresorMockup
//
//  Created by OKU Junichirou on 2018/02/25.
//  Copyright (C) 2018 OKU Junichirou. All rights reserved.
//

import UIKit

enum AppKeyType: Int  {
    case  safety = 0        //  0
    case  reason            //  1
    case  attendability     //  2
    case  family            //  3
    case  house             //  4
    case  cllocation        //  5
    case  placemark         //  6
    case  prefecture        //  7
    case  location          //  8
    case  surroudings       //  9
    case  message           // 10
    case  companyCode       // 11
    case  employeeCode      // 12
    case  toAddress1        // 13
    case  toAddress2        // 14
    case  ccAddress1        // 15
    case  ccAddress2        // 16
    case  mail              // 17
    case  bcpWeb            // 18
    case  info              // 19
    case  typeEnd           // 20

    var description: String {
        var s: String = "**UNKNOWN**AppKeyType"
        switch self {
        case .safety:        s = "Safety"
        case .reason:        s = "Reason"
        case .attendability: s = "Attendability"
        case .family:        s = "Family"
        case .house:         s = "House"
        case .cllocation:    s = "CLLocation"
        case .placemark:     s = "Placemark"
        case .prefecture:    s = "Prefecture"
        case .location:      s = "Location"
        case .surroudings:   s = "Surroudings"
        case .message:       s = "Message"
        case .companyCode:   s = "CompanyCode"
        case .employeeCode:  s = "EmployeeCode"
        case .toAddress1:    s = "ToAddress1"
        case .toAddress2:    s = "ToAddress2"
        case .ccAddress1:    s = "CcAddress1"
        case .ccAddress2:    s = "CcAddress2"
        case .mail:          s = "Mail"
        case .bcpWeb:        s = "BCPWeb"
        case .info:          s = "Info"
        case .typeEnd:       s = "TypeEnd"
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
    case myself = 0
    case home
    case place
    case message
    case send
    case bcpWeb
    case typeEnd

    var description: String {
        var s: String = "**UNKNOWN**SectionType"
        switch self {
        case .myself:  s = "Myself "
        case .home:    s = "Home   "
        case .place:   s = "Place  "
        case .message: s = "Message"
        case .send:    s = "Send   "
        case .bcpWeb:  s = "BCPWeb "
        case .typeEnd: s = "TypeEnd"
        }
        return s
    }

    var header: String {
        return [
            "I am".localized,
            "My Home".localized,
            "Place".localized,
            "Message".localized,
            "",
            "BCP Web".localized,
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
    .safety:        (section: .myself,  row: 0),
    .reason:        (section: .myself,  row: 1),
    .attendability: (section: .myself,  row: 1),
    .family:        (section: .home,    row: 0),
    .house:         (section: .home,    row: 1),
    .prefecture:    (section: .place,   row: 0),
    .location:      (section: .place,   row: 1),
    .surroudings:   (section: .place,   row: 2),
    .message:       (section: .message, row: 0),
    .mail:          (section: .send,    row: 0),
    .bcpWeb:        (section: .bcpWeb,  row: 0)
    ])

class DetailViewController: UIViewController {

    @IBOutlet weak var detailDescriptionLabel: UILabel!


    func configureView() {
        // Update the user interface for the detail item.
        if let detail = detailItem {
            if let label = detailDescriptionLabel {
    //            label.text = detail.timestamp!.description
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
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


}

